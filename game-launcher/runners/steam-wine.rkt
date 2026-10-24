#lang racket
;; runners/steam-wine.rkt - Lançador de jogos Steam executando no Wine
(require racket/system
         racket/string
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt"
         "../wine.rkt")

(provide run-steam-wine)

(define (run-steam-wine g)
  (define wrapper-path (resolve-wrapper-path (game-wrapper g)))
  (define app-id (game-id g))
  (define exe-name (game-exe-name g))
  (define pwsh-exe (get-pwsh-windows-path wrapper-path))

  ;; Parâmetros do PowerShell com -File e bypass de execution policy
  (define ps1-args
    (if (game-ps1-script g)
        (format "\"C:/Scripts/~a\"" (game-ps1-script g))
        (format "-NoProfile -ExecutionPolicy Bypass -File \"C:/Scripts/steam_runner.ps1\" -AppId ~a -ProcessName \"~a\"" app-id exe-name)))

  (define wine-cmd (build-wine-invocation wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g)))
  (define full-cmd (format "~a start \"~a\" ~a >/dev/null" wine-cmd pwsh-exe ps1-args))

  (dynamic-wind
   ;; 1. PRE
   (λ ()
     (printf "🍷 Configurando ambiente Wine para ~a (~a)...
" (game-title g) (game-renderer g))
     (setup-wine-environment wrapper-path (game-renderer g) (game-dll-overrides g) (game-rosetta-x87? g)))

   ;; 2. CORPO
   (λ ()
     (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))
     (printf "🚀 Lançando via Wine e PowerShell: ~a
" ps1-args)
     (unless (system full-cmd) (error 'wine "Wine adapter failed; check the environment file and log."))
     (printf "⏳ Aguardando steam.exe iniciar no Wine...
")
     (wait-for-process "steam.exe")
     (printf "🎮 Sessão de jogo em andamento. Aguardando finalização...
")
     (wait-for-process-exit "steam.exe"))

   ;; 3. POST (Limpeza garantida mesmo em caso de Ctrl+C ou erro)
   (λ ()
     (cleanup-wine wrapper-path)
     (printf "✨ Limpeza de processos do Wine concluída!
"))))
