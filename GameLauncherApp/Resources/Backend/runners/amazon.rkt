#lang racket
;; runners/amazon.rkt - Lançador de jogos Amazon Games via nile
(require racket/system
         racket/string
         racket/path
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt"
         "../wine.rkt")

(provide run-amazon)

(define (run-amazon g)
  (define app-id (if (string? (game-id g)) (game-id g) (number->string (game-id g))))
  (define exe-name (game-exe-name g))
  (define wrapper-path (resolve-wrapper-path (game-wrapper g)))
  (define wine-prefix (format "~a/SharedSupport/prefix" wrapper-path))
  (define launch-cmd
    (format "\"~a\" launch --wine ~a --wine-prefix \"~a\" \"~a\""
            (path->string NILE-BIN)
            wine-launch-argument
            wine-prefix
            app-id))

  (dynamic-wind
   ;; 1. PRE
   (λ ()
     (putenv "STORE" "amazon")
     (putenv "GAMEID" "umu-0")
     (putenv "HEROIC_APP_NAME" app-id)
     (putenv "HEROIC_APP_RUNNER" "nile")
     (putenv "HEROIC_APP_SOURCE" "amazon")
     (putenv "NILE_CONFIG_PATH" (path->string NILE-CONFIG-DIR))
     (printf "🍷 Configurando ambiente Wine para Amazon: ~a (~a)...
" (game-title g) (game-renderer g))
     (setup-wine-environment wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g)))

   ;; 2. CORPO
   (λ ()
     (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
     (printf "🚀 Lançando ~a via nile (Wine)...
" (game-title g))
     (system (format "~a >/dev/null" launch-cmd)))

   ;; 3. POST
   (λ ()
     (cleanup-wine wrapper-path)
     (printf "✨ Limpeza do Wine concluída!
"))))
