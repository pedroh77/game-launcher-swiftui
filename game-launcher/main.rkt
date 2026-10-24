#lang racket
;; main.rkt - Ponto de entrada CLI do Lançador de Jogos Universal
(require racket/cmdline
         racket/system
         racket/match
         racket/string
         "config.rkt"
         "display.rkt"
         "library.rkt"
         "racket-export.rkt"
         "runners/steam-mac.rkt"
         "runners/steam-wine.rkt"
         "runners/gog.rkt"
         "runners/epic.rkt"
         "runners/amazon.rkt"
         "runners/direct.rkt")

;; Use the shared GUI library when present, otherwise preserve the legacy database.
(define GAMES (load-games))

;; Força o modo de buffer de linha no stdout e stderr para exibição imediata
;; tanto no terminal interativo quanto em pipes do Platypus (evita buffer de 4KB)
(when (file-stream-port? (current-output-port))
  (file-stream-buffer-mode (current-output-port) 'line))
(when (file-stream-port? (current-error-port))
  (file-stream-buffer-mode (current-error-port) 'line))

;; Formata a descrição do modo de display para exibição no --info
(define (format-hidpi-info mode)
  (match mode
    [#f "Desativado"]
    [(or #t '2560x1600 "2560x1600" 'default) "Ativado (2560x1600 @ escala 1, mouse 2x)"]
    [(or '2048x1280 "2048x1280") "Ativado (2048x1280 @ escala 1, mouse 2x)"]
    [(or '1680x1050 "1680x1050") "Ativado (1680x1050 @ escala 2, mouse 1.5x - Reshade)"]
    [(or '1920x1200 "1920x1200") "Ativado (1920x1200 @ escala 1, mouse 2x)"]
    [(or '1280x800 "1280x800") "Ativado (1280x800 @ escala 2, mouse 1x)"]
    [other (format "Ativado (~a)" other)]))

;; Lista todos os jogos configurados no banco de dados
(define (list-all-games)
  (printf "
============================================================
")
  (printf "🎮 JOGOS CONFIGURADOS NO LANÇADOR UNIFICADO
")
  (printf "============================================================
")
  (define sorted-keys
    (sort (hash-keys GAMES) string<? #:key symbol->string))
  (for ([key (in-list sorted-keys)])
    (define g (hash-ref GAMES key))
    (printf "  • ~a ~a (~a)
"
            (~a (format "[~a]" key) #:min-width 20)
            (game-title g)
            (game-platform g)))
  (printf "============================================================
")
  (printf "Total: ~a jogos cadastrados.

" (length sorted-keys)))

;; Exibe informações detalhadas de um jogo específico
(define (show-game-info alias-sym)
  (cond
    [(hash-has-key? GAMES alias-sym)
     (define g (hash-ref GAMES alias-sym))
     (printf "
============================================================
")
     (printf "📋 DETALHES DO JOGO: ~a
" (game-title g))
     (printf "============================================================
")
     (printf "  Alias:           ~a
" alias-sym)
     (printf "  Plataforma:      ~a
" (game-platform g))
     (printf "  AppID / ID:      ~a
" (game-id g))
     (printf "  Executável:      ~a
" (game-exe-name g))
     (printf "  HiDPI Switch:    ~a
" (format-hidpi-info (game-hidpi? g)))
     (printf "  Barras Pretas:   ~a
" (if (game-blackbars? g) "Sim" "Não"))
     (printf "  Wine Renderer:   ~a
" (or (game-renderer g) "N/A (Nativo)"))
     (printf "  RosettaX87 JIT:  ~a
" (if (game-rosetta-x87? g) "Ativado" "Desativado"))
     (printf "  Wine Wrapper:    ~a
" (or (game-wrapper g) "N/A (Nativo)"))
     (printf "  DLL Overrides:   ~a
" (or (game-dll-overrides g) "Nenhum"))
     (printf "  Script PS1:      ~a
" (or (game-ps1-script g) "steam_runner.ps1 (Genérico)"))
     (printf "  Automação Foco:  ~a
" (if (procedure? (game-focus-mode g)) "Custom (Lambda)" (or (game-focus-mode g) "Desativado")))
     (printf "============================================================

")]
    [else
     (eprintf "❌ Erro: Jogo com alias '~a' não encontrado!
" alias-sym)
     (exit 1)]))

;; Executa o jogo especificado
(define (launch-game alias-sym)
  (unless (hash-has-key? GAMES alias-sym)
    (eprintf "❌ Erro: Jogo '~a' não encontrado no banco de dados!
" alias-sym)
    (eprintf "Use '--list' para ver todos os aliases disponíveis.
")
    (exit 1))

  (define g (hash-ref GAMES alias-sym))
  (printf "
============================================================
")
  (printf "🎮 INICIANDO: ~a [~a]
" (game-title g) (game-platform g))
  (printf "============================================================
")

  ;; Inicia caffeinate para prevenir sleep durante a jogatina
  (define-values (caff-sp _out _in _err)
    (subprocess #f #f #f "/usr/bin/caffeinate" "-d" "-i"))

  (dynamic-wind
   ;; 1. PRE
   void

   ;; 2. CORPO (com gestão de HiDPI / Blackbars)
   (λ ()
     (with-display-management (game-hidpi? g) (game-blackbars? g)
       (λ ()
         (match (game-platform g)
           ['steam-mac   (run-steam-mac g)]
           ['steam-wine  (run-steam-wine g)]
           ['gog-wine    (run-gog-wine g)]
           ['gog-mac     (run-gog-mac g)]
           ['epic-wine   (run-epic-wine g)]
           ['epic-mac    (run-epic-mac g)]
           ['epic        (run-epic g)]
           ['amazon      (run-amazon g)]
           ['direct      (run-direct g)]
           [other        (error 'launch "Plataforma desconhecida: ~a" other)]))))

   ;; 3. POST (Encerra caffeinate com segurança)
   (λ ()
     (when caff-sp
       (subprocess-kill caff-sp #t)
       (subprocess-wait caff-sp)))))

;; ============================================================
;; PARSER DE LINHA DE COMANDO
;; ============================================================
(define (main)
  (define action 'launch)
  (define export-path #f)
  (define target-alias #f)

  (command-line
   #:program "game-launcher"
   #:once-each
   [("-l" "--list") "Listar todos os jogos cadastrados"
    (set! action 'list)]
   [("-i" "--info") alias "Exibir detalhes do jogo"
    (set! action 'info)
    (set! target-alias (string->symbol alias))]
   [("--export-racket") path "Exportar biblioteca como games.rkt sem substituir arquivos"
    (set! action 'export-racket)
    (set! export-path path)]
   #:args ([alias-arg #f])
   (when (and alias-arg (not target-alias))
     (set! target-alias (string->symbol alias-arg))))

  (match action
    ['export-racket
     (write-racket-library GAMES export-path)]
    ['list
     (list-all-games)]
    ['info
     (if target-alias
         (show-game-info target-alias)
         (begin
           (eprintf "❌ Forneça o alias do jogo para consultar informações. Ex: --info darksouls
")
           (exit 1)))]
    ['launch
     (if target-alias
         (launch-game target-alias)
         (begin
           (printf "Uso: racket main.rkt <alias-do-jogo>
")
           (printf "     racket main.rkt --list
")
           (printf "     racket main.rkt --info <alias>
")))]))

(module+ main (main))
