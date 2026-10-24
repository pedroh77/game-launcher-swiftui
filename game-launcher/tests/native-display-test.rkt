#lang racket
(require rackunit "../native-display.rkt" "../display.rkt"
         (submod "../display.rkt" test-support))

(define (with-owner value thunk)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set! env #"GAME_LAUNCHER_NATIVE_DISPLAY" (and value (string->bytes/utf-8 value)))
  (parameterize ([current-environment-variables env]
                 [current-resolution-command (lambda args (fail "Unexpected RDM call"))]
                 [current-pointer-command (lambda args (fail "Unexpected pointer adjustment"))])
    (thunk)))

(module+ test
  (test-case "absent ownership leaves legacy path selected"
    (with-owner #f (lambda () (check-eq? (native-display-state) 'legacy))))
  (test-case "ownership parses exact resolution and scale"
    (with-owner "2048,1280,1"
      (lambda ()
        (check-equal? (native-display-state) '(2048 1280 1))
        (check-true (native-profile-matches? (native-display-state) 2048 1280 1.0))
        (check-false (native-profile-matches? (native-display-state) 2048 1280 2)))))
  (test-case "invalid markers fail closed"
    (for ([value '("false" "2048,1280,3" "-1,1280,1" "2048,1280" ",2048,1280,1," "2048,1280,1\n")])
      (with-owner value (lambda () (check-exn exn:fail? native-display-state)))))
  (test-case "skip never adjusts pointer resolution or blackbars"
    (with-owner "skip"
      (lambda ()
        (check-equal? (with-display-management '2048x1280 #t (lambda () 'game-body)) 'game-body))))
  (test-case "changed live profile fails before running a game"
    (with-owner "2048,1280,1"
      (lambda ()
        (check-exn exn:fail? (lambda () (with-display-management '2560x1600 #f (lambda () (fail "Game ran")))))
        (check-exn exn:fail? (lambda () (with-display-management #f #f (lambda () (fail "Game ran"))))))))
  (test-case "native normal completion retains pointer policy without RDM"
    (with-owner "2048,1280,1"
      (lambda ()
        (define calls '())
        (parameterize ([current-pointer-command (lambda (value) (set! calls (append calls (list value))))])
          (check-equal? (with-display-management '2048x1280 #f
                          (lambda () (set! calls (append calls '(game))) 'done)) 'done)
          (check-equal? calls '(2.0 game 1.0))))))
  (test-case "native game failure still unwinds pointer cleanup"
    (with-owner "2048,1280,1"
      (lambda ()
        (define calls '())
        (parameterize ([current-pointer-command (lambda (value) (set! calls (append calls (list value))))])
          (check-exn exn:fail? (lambda () (with-display-management '2048x1280 #f (lambda () (error 'mock "game failed")))))
          (check-equal? calls '(2.0 1.0))))))
  (test-case "native set-resolution never calls RDM"
    ;; Safe even on a Mac with RDM installed: ownership suppresses both writes.
    (with-owner "2048,1280,1"
      (lambda ()
        (check-true (void? (set-resolution 2048 1280 1)))
        (check-true (void? (set-resolution 1440 900 2)))))))
