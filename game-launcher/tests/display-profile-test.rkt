#lang racket
;; Pure configuration checks: no display changes, pointer changes, or helpers run.
(require rackunit "../display.rkt" "../library.rkt")

(module+ test
  (test-case "2048x1280 uses scale 1 and pointer 2.0 for both profile keys"
    (for ([key '(2048x1280 "2048x1280")])
      (define profile (hash-ref DISPLAY-PROFILES key))
      (check-equal? profile (display-profile 2048 1280 1 2.0))
      (check-equal? (vector-copy (struct->vector profile) 3)
                    (vector-copy (struct->vector (hash-ref DISPLAY-PROFILES '2560x1600)) 3))))
  (test-case "existing default profile aliases remain 2560x1600"
    (for ([key '(#t default 2560x1600 "2560x1600")])
      (check-equal? (hash-ref DISPLAY-PROFILES key)
                    (display-profile 2560 1600 1 2.0))))
  (test-case "2048x1280 round-trips without changing other game settings"
    (define original
      (game "Display Test" 'steam-wine 123 "Game.exe"
            #:hidpi? '2048x1280 #:blackbars? #t #:focus-mode 6
            #:focus-coords "1919,1079"))
    (define games (hash 'display-test original))
    (define doc (games->jsexpr games))
    (check-equal? (hash-ref (car (hash-ref doc 'games)) 'displayMode) "2048x1280")
    (check-false (hash-has-key? (car (hash-ref doc 'games)) 'customDisplay))
    (check-equal? (jsexpr->games doc) games)
    (check-equal? (games->jsexpr (jsexpr->games doc)) doc)))
