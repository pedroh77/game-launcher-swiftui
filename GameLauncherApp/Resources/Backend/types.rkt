#lang racket
;; types.rkt - Definição da estrutura de dados de jogos e construtores
(provide (all-defined-out))

;; ============================================================
;; STRUCT BASE DO JOGO
;; ============================================================
(struct game-record (
  title
  platform
  id
  exe-name
  hidpi?
  blackbars?
  renderer
  rosetta-x87?
  wrapper
  dll-overrides
  game-dir
  save-dir
  ps1-script
  focus-mode
  focus-coords
) #:transparent)

;; Accessores explícitos
(define game-title game-record-title)
(define game-platform game-record-platform)
(define game-id game-record-id)
(define game-exe-name game-record-exe-name)
(define game-hidpi? game-record-hidpi?)
(define game-blackbars? game-record-blackbars?)
(define game-renderer game-record-renderer)
(define game-rosetta-x87? game-record-rosetta-x87?)
(define game-wrapper game-record-wrapper)
(define game-dll-overrides game-record-dll-overrides)
(define game-game-dir game-record-game-dir)
(define game-save-dir game-record-save-dir)
(define game-ps1-script game-record-ps1-script)
(define game-focus-mode game-record-focus-mode)
(define game-focus-coords game-record-focus-coords)

;; Construtor declarativo com argumentos nomeados e valores padrão
(define (game title platform id exe-name
              #:hidpi?           [hidpi? #t]
              #:blackbars?       [blackbars? #f]
              #:renderer         [renderer 'd3dmetal]
              #:rosetta-x87?     [rosetta-x87? #t]
              #:wrapper          [wrapper "Steam_SK.app"]
              #:dll-overrides    [dll-overrides #f]
              #:game-dir         [game-dir #f]
              #:save-dir         [save-dir #f]
              #:ps1-script       [ps1-script #f]
              #:focus-mode       [focus-mode 6]
              #:focus-coords     [focus-coords #f])
  (game-record title platform id exe-name
               hidpi? blackbars? renderer rosetta-x87? wrapper dll-overrides
               game-dir save-dir ps1-script focus-mode focus-coords))
