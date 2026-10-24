#lang racket
;; native-display-owner-v1
;; display.rkt - Gerenciamento de resolução HiDPI, sensibilidade do mouse e blackbars
(require racket/system
         racket/match
         racket/string
         "config.rkt"
         "native-display.rkt")

(provide with-display-management
         get-current-resolution
         set-resolution
         set-pointer-scale
         display-profile
         DISPLAY-PROFILES)

;; Struct para parâmetros de perfil de exibição
(struct display-profile (
  width
  height
  rdm-scale
  pointer-scale
) #:transparent)

;; Banco de perfis de exibição predefinidos
(define DISPLAY-PROFILES
  (hash
   ;; Padrão (2560x1600 nativo) -> escala RDM 1, mouse/trackpad 2.0
   '2560x1600 (display-profile 2560 1600 1 2.0)
   "2560x1600" (display-profile 2560 1600 1 2.0)
   #t          (display-profile 2560 1600 1 2.0)
   'default    (display-profile 2560 1600 1 2.0)

   ;; Canvas 2048x1280 -> mesma escala e ponteiro do perfil 2560x1600
   '2048x1280 (display-profile 2048 1280 1 2.0)
   "2048x1280" (display-profile 2048 1280 1 2.0)

   ;; Canvas intermediário Reshade (1680x1050) -> escala RDM 2, mouse/trackpad 1.5
   '1680x1050 (display-profile 1680 1050 2 1.5)
   "1680x1050" (display-profile 1680 1050 2 1.5)

   ;; Canvas 1920x1200 -> escala RDM 1, mouse/trackpad 2.0
   '1920x1200 (display-profile 1920 1200 1 2.0)
   "1920x1200" (display-profile 1920 1200 1 2.0)

   ;; Canvas 1280x800 -> escala RDM 2, mouse/trackpad 1.0
   '1280x800  (display-profile 1280 800 2 1.0)
   "1280x800"  (display-profile 1280 800 2 1.0)))

;; Perfil padrão de restauração do macOS
(define RESTORE-PROFILE (display-profile 1440 900 2 1.0))

;; Resolve o modo especificado em uma struct display-profile
(define (resolve-display-profile mode)
  (cond
    [(not mode) #f]
    [(display-profile? mode) mode]
    [(match mode
       [(list w h s p) (display-profile w h s p)]
       [_ #f])]
    [(hash-has-key? DISPLAY-PROFILES mode)
     (hash-ref DISPLAY-PROFILES mode)]
    [else
     (printf "⚠️ Perfil de display '~a' não reconhecido. Usando padrão (2560x1600).
" mode)
     (hash-ref DISPLAY-PROFILES #t)]))

;; Obtém a resolução lógica atual através do Finder
(define (get-current-resolution)
  (define out
    (with-output-to-string
      (λ ()
        (system "osascript -e 'tell application \"Finder\" to get bounds of window of desktop' 2>/dev/null"))))
  (match (string-split (string-trim out) ", ")
    [(list _ _ w h) (format "~ax~a" w h)]
    [_ "1920x1080"]))

;; Aplica resolução via RDM
(define current-resolution-command
  (make-parameter
   (lambda (w h scale)
     (when (file-exists? RDM-PATH)
       (system* RDM-PATH "-s" (number->string scale) "-w" (number->string w) "-h" (number->string h)))
     (void))))
(define (set-resolution w h scale)
  (when (eq? (native-display-state) 'legacy)
    ((current-resolution-command) w h scale)))

;; Ajusta sensibilidade de trackpad e mouse
(define (apply-pointer-scale val)
  (define val-str (number->string val))
  (system* "/usr/bin/defaults" "write" "NSGlobalDomain" "com.apple.trackpad.scaling" "-float" val-str)
  (system* "/usr/bin/defaults" "write" "NSGlobalDomain" "com.apple.mouse.scaling" "-float" val-str)
  (when (file-exists? ACTIVATE-SETTINGS-BIN)
    (system* ACTIVATE-SETTINGS-BIN "-u"))
  (void))

(define current-pointer-command (make-parameter apply-pointer-scale))
(define (set-pointer-scale val) ((current-pointer-command) val))

;; Explicit test seam: regression tests cannot accidentally call real macOS tools.
(module+ test-support (provide current-resolution-command current-pointer-command))

;; Gerenciador de contexto seguro para HiDPI e Blackbars com perfis flexíveis
(define (with-display-management hidpi-mode blackbars? thunk)
  (define profile (resolve-display-profile hidpi-mode))
  (define owner (native-display-state))
  (when (list? owner)
    (unless (and profile
                 (native-profile-matches? owner (display-profile-width profile)
                                          (display-profile-height profile)
                                          (display-profile-rdm-scale profile)))
      (error 'native-display "The game display profile changed after native preflight. Refusing to launch.")))
  (if (or (not profile) (eq? owner 'skip))
      (thunk)
      (let ([cur-res (if (eq? owner 'legacy) (get-current-resolution) "native-managed")])
        (if (string=? cur-res "1920x1080")
            (begin
              (printf "🖥️ Monitor externo 1080p detectado — mantendo resolução atual.
")
              (thunk))
            (let ([bb-proc #f]
                  [w (display-profile-width profile)]
                  [h (display-profile-height profile)]
                  [rdm-scale (display-profile-rdm-scale profile)]
                  [ptr-scale (display-profile-pointer-scale profile)])
              (dynamic-wind
               ;; 1. PRE: Ajuste de resolução, ponteiro e blackbars
               (λ ()
                 (printf "⚡ Ajustando display para modo jogo (~ax~a @ escala ~a, ponteiro ~ax)...
"
                         w h rdm-scale ptr-scale)
                 (set-resolution w h rdm-scale)
                 (set-pointer-scale ptr-scale)
                 (when (and blackbars? (file-exists? BLACKBARS-PATH))
                   (printf "🖤 Iniciando helper de barras pretas (blackbars)...
")
                   (let-values ([(sp _out _in _err) (subprocess #f #f #f (path->string BLACKBARS-PATH))])
                     (set! bb-proc sp))))

               ;; 2. CORPO: Execução do jogo
               thunk

               ;; 3. POST: Restauração garantida
               (λ ()
                 (when bb-proc
                   (printf "🖤 Encerrando blackbars...
")
                   (subprocess-kill bb-proc #t)
                   (subprocess-wait bb-proc))
                 (printf "🔄 Restaurando configurações originais do macOS (1440x900 @ escala 2, ponteiro 1x)...
")
                 (set-resolution (display-profile-width RESTORE-PROFILE)
                                 (display-profile-height RESTORE-PROFILE)
                                 (display-profile-rdm-scale RESTORE-PROFILE))
                 (set-pointer-scale (display-profile-pointer-scale RESTORE-PROFILE))
                 (if (eq? owner 'legacy)
                     (printf "✅ Configurações de display restauradas!\n")
                     (printf "✅ Ponteiro restaurado; o app concluirá a restauração nativa após a limpeza.\n")))))))))
