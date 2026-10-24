#lang racket
;; native-input-owner-v1
;; focus.rkt - Automação assíncrona de foco, cliques com cliclick e cursorcerer
(require racket/system
         racket/match
         "config.rkt"
         "native-input.rkt")

(provide start-focus-thread
         wait-for-process
         wait-for-process-exit
         hide-cursor
         click)

;; Atalho de teclado para ocultar ponteiro do mouse (Cursorcerer)
(define (hide-cursor)
  (if (native-input-enabled?)
      (native-input-request "hide")
      (system "osascript -e 'tell application \"System Events\" to keystroke \"k\" using {control down, option down}' >/dev/null 2>&1"))
  (void))

;; Executa clique em coordenadas específicas via cliclick
(define (click coords [times 1])
  (if (native-input-enabled?)
      (for ([_ (in-range times)]) (native-input-request "click" coords))
      (when (file-exists? CLICLICK-PATH)
        (for ([_ (in-range times)])
          (system* CLICLICK-PATH (format "c:~a" coords))))))

;; Read commands directly, without interpolating the game name into a shell/regex.
;; -ww prevents long executable paths from being truncated.
(define current-process-commands
  (make-parameter
   (lambda ()
     (string-split
      (with-output-to-string
        (lambda ()
          (unless (system* "/bin/ps" "-ww" "-axo" "command=")
            (error 'process-running? "Could not read the process list"))))
      "\n"))))

(define launcher-command-pattern
  #px"(?i:grep|steam_runner|main\\.rkt|game-launcher|\\bplay\\b|pwsh\\.exe -File|(?:^|/)GameRunner(?:\\s|$)|/Game Launcher\\.app/Contents/MacOS/)")

(define (process-command-matches? name command)
  (and (not (string=? name ""))
       (string-contains? (string-downcase command) (string-downcase name))
       (not (regexp-match? launcher-command-pattern command))))

;; A standalone GameRunner lives in a bundle named after the game. It must not
;; keep its own monitoring loop alive after the real game executable has exited.
(define (process-running? name)
  (for/or ([command (in-list ((current-process-commands)))])
    (process-command-matches? name command)))

(module+ test-support
  (provide process-command-matches? process-running? current-process-commands))

;; Aguarda até que o executável real do jogo apareça
(define (wait-for-process name [poll-interval 2])
  (printf "⏳ Aguardando processo '~a' iniciar...
" name)
  (let loop ()
    (define running? (process-running? name))
    (unless running?
      (sleep poll-interval)
      (loop)))
  (printf "🎯 Processo '~a' detectado!
" name))

;; Aguarda até que o processo do jogo/Steam feche
(define (wait-for-process-exit name [poll-interval 3])
  (printf "⏳ Monitorando execução de '~a'...
" name)
  (let loop ()
    (define running? (process-running? name))
    (when running?
      (sleep poll-interval)
      (loop)))
  (printf "🏁 Processo '~a' finalizado!
" name))

;; Inicia a automação de foco em uma thread assíncrona
(define (start-focus-thread exe-name focus-mode focus-coords)
  (match focus-mode
    ;; Sem automação de foco
    [#f (void)]

    ;; Função personalizada
    [(? procedure? custom-proc)
     (thread
      (λ ()
        (printf "🤖 Iniciando rotina personalizada de foco...
")
        (custom-proc)))]

    ;; Modo padrão com delay numérico em segundos
    [(? number? delay-secs)
     (thread
      (λ ()
        (wait-for-process exe-name)
        (sleep delay-secs)
        (define coords (or focus-coords "1919,1079"))
        (printf "🖱️ Executando clique de foco em (~a) e ocultando cursor...
" coords)
        (click coords)
        (click coords)
        (hide-cursor)
        (sleep 3)
        (click coords)
        (when (native-input-enabled?)
          (hide-cursor))))]))
