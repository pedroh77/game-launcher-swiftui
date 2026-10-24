#lang racket
;; runners/gog.rkt - Lançador de jogos GOG (gogdl com suporte a cloud sync e comet)
(require racket/system
         racket/string
         racket/path
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt"
         "../wine.rkt")

(provide run-gog-wine
         run-gog-mac)

(define (run-gog-wine g)
  (define wrapper-path (resolve-wrapper-path (game-wrapper g)))
  (define app-id (game-id g))
  (define exe-name (game-exe-name g))
  (define game-dir (or (game-game-dir g)
                       (format "~a/SharedSupport/prefix/drive_c/Program Files (x86)/GOG Galaxy/Games/~a" wrapper-path (game-title g))))
  (define wine-prefix (format "~a/SharedSupport/prefix" wrapper-path))
  (define launch-cmd
    (format "\"~a\" --auth-config-path \"~a\" launch \"~a\" \"~a\" --wine ~a --wine-prefix \"~a\" --platform windows"
            (path->string GOGDL-BIN)
            (path->string GOG-AUTH-FILE)
            game-dir
            app-id
            wine-launch-argument
            wine-prefix))

  (define comet-running? #f)

  (dynamic-wind
   ;; 1. PRE
   (λ ()
     (printf "🍷 Configurando ambiente Wine para GOG: ~a (~a)...
" (game-title g) (game-renderer g))
     (setup-wine-environment wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g))
     (putenv "STORE" "gog")
     (putenv "GAMEID" "umu-0")
     (putenv "HEROIC_APP_NAME" (if (string? app-id) app-id (number->string app-id)))
     (putenv "HEROIC_APP_RUNNER" "gog")
     (putenv "HEROIC_APP_SOURCE" "gog")
     (putenv "GOG_AUTH" (path->string GOG-AUTH-FILE))
     (putenv "GOGDL_CONFIG_PATH" (path->string GOGDL-CONFIG-DIR)))

   ;; 2. CORPO
   (λ ()
     (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
     (when (system "which comet >/dev/null 2>&1")
       (system "comet --from-heroic --username \"pedroh7@gmail.com\" --quit >/dev/null 2>&1 &")
       (set! comet-running? #t))
     (printf "🚀 Lançando ~a via gogdl (Wine)...
" (game-title g))
     (system (format "~a >/dev/null" launch-cmd))
     (printf "🎮 Jogo fechado.
")
     (when (game-save-dir g)
       (let* ([full-save-dir
               (if (string-prefix? (game-save-dir g) "/")
                   (game-save-dir g)
                   (format "~a/SharedSupport/prefix/drive_c/~a" wrapper-path (game-save-dir g)))]
              [sync-cmd
               (format "\"~a\" --auth-config-path \"~a\" save-sync --ts \"~a\" --os windows \"~a\" \"~a\""
                       (path->string GOGDL-BIN)
                       (path->string GOG-AUTH-FILE)
                       (current-seconds)
                       full-save-dir
                       app-id)])
         (printf "☁️ Sincronizando saves do GOG com a nuvem...
")
         (system (format "~a >/dev/null" sync-cmd))
         (printf "✅ Saves sincronizados com sucesso!
"))))

   ;; 3. POST
   (λ ()
     (when comet-running?
       (system "pkill -f comet >/dev/null 2>&1"))
     (cleanup-wine wrapper-path)
     (printf "✨ Limpeza do Wine finalizada!
"))))

(define (run-gog-mac g)
  (define app-id (game-id g))
  (define exe-name (game-exe-name g))
  (define game-dir (or (game-game-dir g) (format "/Applications/~a.app" (game-title g))))
  (define launch-cmd
    (format "\"~a\" --auth-config-path \"~a\" launch \"~a\" \"~a\" --platform osx"
            (path->string GOGDL-BIN)
            (path->string GOG-AUTH-FILE)
            game-dir
            app-id))

  (putenv "GOG_AUTH" (path->string GOG-AUTH-FILE))
  (putenv "GOGDL_CONFIG_PATH" (path->string GOGDL-CONFIG-DIR))

  (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))

  (printf "🚀 Lançando ~a via gogdl (Mac Nativo)...
" (game-title g))
  (system launch-cmd)

  (when (game-save-dir g)
    (let ([sync-cmd
           (format "\"~a\" --auth-config-path \"~a\" save-sync --ts \"~a\" --os osx \"~a\" \"~a\""
                   (path->string GOGDL-BIN)
                   (path->string GOG-AUTH-FILE)
                   (current-seconds)
                   (expand-user-path (game-save-dir g))
                   app-id)])
      (printf "☁️ Sincronizando saves do GOG com a nuvem...
")
      (system sync-cmd)))

  (printf "✨ ~a finalizado com sucesso!
" (game-title g)))
