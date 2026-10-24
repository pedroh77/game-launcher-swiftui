#lang racket
(require rackunit json racket/runtime-path
         "../library.rkt" (prefix-in legacy: "../games.rkt"))
(define-runtime-path seed "../games.seed.json")
(define source (games->jsexpr legacy:GAMES))
(define migrated (read-library seed))
(define row (car (hash-ref source 'games)))
(define (single r) (hash 'schemaVersion 1 'games (list r)))

(module+ test
  (test-case "all legacy entries round-trip without changing their effective configuration"
    (check-equal? (hash-count migrated) 118)
    (check-equal? (games->jsexpr migrated) source)
    (for ([(alias original) (in-hash legacy:GAMES)])
      (define reloaded (hash-ref migrated alias))
      (define a (hash-ref (games->jsexpr (hash alias original)) 'games))
      (define b (hash-ref (games->jsexpr (hash alias reloaded)) 'games))
      (check-equal? a b (symbol->string alias))))
  (test-case "legacy defaults and special entries are preserved, not guessed"
    (check-equal? (game-wrapper (hash-ref migrated 'thefallepic)) "Steam_SK.app")
    (check-equal? (game-hidpi? (hash-ref migrated 'rotn)) '1680x1050)
    (check-false (game-focus-mode (hash-ref migrated 'hades))))
  (test-case "native direct launch is represented by an explicit null wrapper"
    (define native (jsexpr->games (single (hash-set* row 'platform "direct" 'wrapper 'null 'id "/Applications/Game.app/Contents/MacOS/Game"))))
    (check-false (game-wrapper (car (hash-values native)))))
  (test-case "custom display fields map to the existing list representation"
    (define doc (single (hash-set* row 'displayMode "custom" 'customDisplay (hash 'width 1600 'height 1000 'scale 2 'pointerScale 1.5))))
    (check-equal? (game-hidpi? (car (hash-values (jsexpr->games doc)))) '(1600 1000 2 1.5)))
  (test-case "unknown metadata is tolerated by the launch reader"
    (check-equal? (jsexpr->games (hash-set (single (hash-set row 'futureOption (hash 'enabled #t))) 'futureRoot "value"))
                  (jsexpr->games (single row))))
  (test-case "invalid versions, duplicate aliases and malformed values are rejected"
    (check-exn exn:fail? (lambda () (jsexpr->games (hash-set source 'schemaVersion 2))))
    (check-exn exn:fail? (lambda () (jsexpr->games (hash 'schemaVersion 1 'games (list row row)))))
    (for ([key '(alias platform renderer displayMode focusDelay focusCoords blackbars wrapper)]
          [value '("bad alias" "unknown" "unknown" "unknown" -1 "x,y" "yes" 12)])
      (check-exn exn:fail? (lambda () (jsexpr->games (single (hash-set row key value)))))))
  (test-case "shell substitutions rejected while legacy path placeholders remain valid"
    (for ([value '("$(touch /tmp/no)" "bad`command`" "bad\"quote" "C:\\Games")])
      (check-exn exn:fail? (lambda () (jsexpr->games (single (hash-set row 'gameDir value))))))
    (for ([value '("$WRAPPER/SharedSupport/prefix/drive_c/Game" "$HOME/Games" "/Games/Kathy’s Game")])
      (check-not-exn (lambda () (jsexpr->games (single (hash-set row 'gameDir value)))))))
  (test-case "Steam ID cannot inject an unquoted shell argument"
    (check-exn exn:fail? (lambda () (jsexpr->games (single (hash-set row 'id "123; echo bad"))))))
  (test-case "custom focus procedures are not silently discarded by migration"
    (check-exn exn:fail? (lambda () (games->jsexpr (hash 'custom (game "Custom" 'direct "a" "a" #:focus-mode void))))))
  (test-case "explicit missing library never silently falls back to legacy data"
    (parameterize ([current-environment-variables (environment-variables-copy (current-environment-variables))])
      (putenv "GAME_LAUNCHER_LIBRARY" "/nonexistent/game-launcher-test-library.json")
      (check-exn exn:fail? load-games)
      (putenv "GAME_LAUNCHER_LIBRARY" (path->string seed))
      (check-equal? (load-games) migrated)))
  (test-case "trailing JSON is rejected"
    (define temp (make-temporary-file "game-library-test-~a.json"))
    (dynamic-wind void
                  (lambda ()
                    (call-with-output-file temp (lambda (out) (write-json source out) (display " {}" out)) #:exists 'truncate)
                    (check-exn exn:fail? (lambda () (read-library temp))))
                  (lambda () (delete-file temp)))))

(module+ test
  (test-case "integral JSON decimal values are normalized for Swift encoder compatibility"
    (define doc
      (hash 'schemaVersion 1.0
            'games (list (hash-set* row 'id 1701520.0 'displayMode "custom"
                                   'customDisplay (hash 'width 1600.0 'height 1000.0 'scale 2.0 'pointerScale 1.5)))))
    (define g (car (hash-values (jsexpr->games doc))))
    (check-equal? (game-id g) 1701520)
    (check-equal? (game-hidpi? g) '(1600 1000 2 1.5))))
