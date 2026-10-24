#lang racket
;; runners/steam-mac.rkt - Lançador de jogos nativos Steam para macOS
(require racket/system
         "../config.rkt"
         "../types.rkt"
         "../focus.rkt")

(provide run-steam-mac)

(define (run-steam-mac g)
  (define app-id (game-id g))
  (define exe-name (game-exe-name g))

  (printf "🚀 Lançando ~a via Steam Mac (AppID: ~a)...
" (game-title g) app-id)

  ;; 1. Inicia automação de foco em background (se configurada)
  (start-focus-thread exe-name (game-focus-mode g) (game-focus-coords g))

  ;; 2. Inicia o jogo via URL scheme do Steam em background
  (system (format "\"~a\" steam://rungameid/~a >/dev/null 2>&1 &" STEAM-MAC-BIN app-id))

  ;; 3. Aguarda o processo do jogo iniciar e depois finalizar
  (wait-for-process exe-name)
  (wait-for-process-exit exe-name)

  ;; 4. Aguarda sincronização do Steam Cloud (10 segundos padrão)
  (printf "☁️ Jogo encerrado. Aguardando 10s para sincronização da Steam Cloud...
")
  (sleep 10)

  ;; 5. Fecha o Steam de forma suave via AppleScript
  (printf "🛑 Solicitando encerramento do Steam...
")
  (system "osascript -e 'tell application \"Steam\" to quit' >/dev/null 2>&1")
  (printf "✨ ~a finalizado com sucesso!
" (game-title g)))
