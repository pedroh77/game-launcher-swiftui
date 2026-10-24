#lang racket
;; Data-only compatibility export. Never launches games or modifies the library.
(require racket/pretty "library.rkt")
(provide games->racket write-racket-library)

(define (quoted value) (list 'quote value))
(define (display-value mode)
  ;; Explicit profiles also work with older display.rkt versions which do not
  ;; know the newer 2048x1280 profile name.
  (match mode
    [#f #f]
    [(or #t 'default '2560x1600 "2560x1600") '(2560 1600 1 2)]
    [(or '2048x1280 "2048x1280") '(2048 1280 1 2)]
    [(or '1680x1050 "1680x1050") '(1680 1050 2 1.5)]
    [(or '1920x1200 "1920x1200") '(1920 1200 1 2)]
    [(or '1280x800 "1280x800") '(1280 800 2 1)]
    [(list w h s p) (list w h s p)]
    [_ (error 'racket-export "Unsupported display profile: ~e" mode)]))

(define (game-expression g)
  (when (procedure? (game-focus-mode g))
    (error 'racket-export "Custom focus procedures cannot be exported as data."))
  `(game ,(game-title g) ,(quoted (game-platform g)) ,(game-id g) ,(game-exe-name g)
         #:hidpi? ,(let ([mode (display-value (game-hidpi? g))]) (if mode (quoted mode) #f))
         #:blackbars? ,(game-blackbars? g)
         #:renderer ,(quoted (game-renderer g))
         #:rosetta-x87? ,(game-rosetta-x87? g)
         #:wrapper ,(game-wrapper g)
         #:dll-overrides ,(game-dll-overrides g)
         #:game-dir ,(game-game-dir g)
         #:save-dir ,(game-save-dir g)
         #:ps1-script ,(game-ps1-script g)
         #:focus-mode ,(game-focus-mode g)
         #:focus-coords ,(game-focus-coords g)))

(define (games->racket games)
  (with-output-to-string
    (lambda ()
      (display "#lang racket\n;; Exported game settings. Requires your existing types.rkt alongside this file.\n;; JSON remains the master library; notes/unknown JSON fields are not represented.\n;; This export does not change display/focus implementations or install a backend.\n(require \"types.rkt\")\n(provide GAMES (all-from-out \"types.rkt\"))\n\n")
      (parameterize ([pretty-print-columns 100])
        (pretty-write
         `(define GAMES
            (hash ,@(append-map
                     (lambda (alias)
                       (list (quoted alias) (game-expression (hash-ref games alias))))
                     (sort (hash-keys games) symbol<?)))))))))

(define (write-racket-library games destination)
  ;; Construct/validate before touching the destination. Never overwrite a file.
  (define text (games->racket games))
  (call-with-output-file destination (lambda (out) (display text out)) #:exists 'error))
