#lang racket
;; runners/epic.rkt - Lançador de jogos Epic Games via legendary (Nativo Mac ou Wine)
(require racket/system
         racket/string
         racket/path
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt"
         "../wine.rkt")

(provide run-epic
         run-epic-mac
         run-epic-wine)

(define (run-epic-wine g)
  (define app-name (if (string? (game-id g)) (game-id g) (number->string (game-id g))))
  (define exe-name (game-exe-name g))
  (define wrapper-path (resolve-wrapper-path (game-wrapper g)))
  (define wine-prefix (format "~a/SharedSupport/prefix" wrapper-path))
  (define launch-cmd
    (format "\"~a\" launch \"~a\" --wine ~a --wine-prefix \"~a\" --language pt_BR --skip-version-check"
            (path->string LEGENDARY-BIN)
            app-name
            wine-launch-argument
            wine-prefix))

  (dynamic-wind
   ;; 1. PRE
   (λ ()
     (putenv "STORE" "egs")
     (putenv "GAMEID" "umu-0")
     (putenv "HEROIC_APP_NAME" app-name)
     (putenv "HEROIC_APP_RUNNER" "legendary")
     (putenv "HEROIC_APP_SOURCE" "epic")
     (putenv "LEGENDARY_CONFIG_PATH" (path->string LEGENDARY-CONFIG-DIR))
     (printf "🍷 Configurando ambiente Wine para Epic: ~a (~a)...
" (game-title g) (game-renderer g))
     (setup-wine-environment wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g)))

   ;; 2. CORPO
   (λ ()
     (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
     (printf "🚀 Lançando ~a via legendary (Wine)...
" (game-title g))
     (system (format "~a >/dev/null" launch-cmd)))

   ;; 3. POST
   (λ ()
     (cleanup-wine wrapper-path)
     (printf "✨ Limpeza do Wine concluída!
"))))

(define (run-epic-mac g)
  (define app-name (if (string? (game-id g)) (game-id g) (number->string (game-id g))))
  (define exe-name (game-exe-name g))
  (define launch-cmd
    (format "\"~a\" launch \"~a\" --language pt_BR --skip-version-check"
            (path->string LEGENDARY-BIN)
            app-name))

  (putenv "STORE" "egs")
  (putenv "GAMEID" "umu-0")
  (putenv "HEROIC_APP_NAME" app-name)
  (putenv "HEROIC_APP_RUNNER" "legendary")
  (putenv "HEROIC_APP_SOURCE" "epic")
  (putenv "LEGENDARY_CONFIG_PATH" (path->string LEGENDARY-CONFIG-DIR))

  (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
  (printf "🚀 Lançando ~a via legendary (Mac Nativo)...
" (game-title g))
  (system launch-cmd)
  (printf "✨ ~a finalizado com sucesso!
" (game-title g)))

(define (run-epic g)
  (if (game-wrapper g)
      (run-epic-wine g)
      (run-epic-mac g)))
