#lang racket
;; runners/direct.rkt - Lançador de executáveis diretos (Wine ou Nativo)
(require racket/system
         racket/string
         racket/path
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt"
         "../wine.rkt")

(provide run-direct)

(define (run-direct g)
  (define exe-path (game-id g))
  (define exe-name (game-exe-name g))
  (define is-wine? (game-wrapper g))

  (cond
    [is-wine?
     (let* ([wrapper-path (resolve-wrapper-path (game-wrapper g))]
            [wine-cmd (build-wine-invocation wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g))]
            [full-cmd
             (if (game-game-dir g)
                 (format "cd \"~a\" && ~a \"~a\" >/dev/null" (game-game-dir g) wine-cmd exe-path)
                 (format "~a start \"\" \"~a\" >/dev/null" wine-cmd exe-path))])
       (dynamic-wind
        ;; 1. PRE
        (λ ()
          (printf "🍷 Configurando ambiente Wine para executável direto: ~a (~a)...
" (game-title g) (game-renderer g))
          (setup-wine-environment wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g)))
        ;; 2. CORPO
        (λ ()
          (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
          (printf "🚀 Lançando ~a via Wine...
" (game-title g))
          (unless (system full-cmd) (error 'wine "Wine adapter failed; check the environment file and log."))
          (wait-for-process exe-name)
          (wait-for-process-exit exe-name))
        ;; 3. POST
        (λ ()
          (cleanup-wine wrapper-path)
          (printf "✨ Limpeza do Wine concluída!
"))))]

    [else
     (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
     (printf "🚀 Lançando ~a (Mac Nativo)...
" (game-title g))
     (if (game-game-dir g)
         (system (format "cd \"~a\" && \"~a\" &" (game-game-dir g) exe-path))
         (system (format "\"~a\" &" exe-path)))
     (wait-for-process exe-name)
     (wait-for-process-exit exe-name)
     (printf "✨ ~a finalizado com sucesso!
" (game-title g))]))
