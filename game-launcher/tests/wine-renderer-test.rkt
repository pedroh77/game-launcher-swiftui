#lang racket
;; Boundary tests only: no Wine, display, focus or process-cleanup commands run.
(require rackunit racket/runtime-path
         "../wine.rkt" "../library.rkt")

(define-runtime-path seed-path "../games.seed.json")
(define renderers '(d3dmetal dxvk dxmt mtld3d d9mt none))
(define wrapper "/Applications/Test Wrapper.app/Contents")

;; setup-wine-environment validates the live file and sets environment variables;
;; it does not source it. Keep those variables and the empty fixture isolated.
(define (with-fixture-environment thunk)
  (define live (make-temporary-file "wine-renderer-env-~a.sh"))
  (dynamic-wind
   void
   (lambda ()
     (parameterize ([current-environment-variables
                     (environment-variables-copy (current-environment-variables))])
       (putenv "GAME_LAUNCHER_WINE_ENV" (path->string live))
       (thunk)))
   (lambda () (delete-file live))))

(module+ test
  (test-case "command builder accepts game-record symbols and existing string callers"
    (for ([renderer renderers])
      (define name (symbol->string renderer))
      (define cmd (build-wine-invocation wrapper renderer "dxgi=n,b" #f))
      (check-equal? cmd (build-wine-invocation wrapper name "dxgi=n,b" #f))
      (check-true (string-contains? cmd (format "RENDERER='~a' " name)))
      (check-true (string-contains? cmd "GAME_LAUNCHER_USE_ROSETTA=0 "))))

  (test-case "environment setup converts every supported renderer symbol"
    (with-fixture-environment
     (lambda ()
       (for ([renderer renderers])
         (setup-wine-environment wrapper renderer)
         (check-equal? (getenv "RENDERER") (symbol->string renderer))))))

  (test-case "environment setup preserves string renderer callers"
    (with-fixture-environment
     (lambda ()
       (for ([renderer renderers])
         (define name (symbol->string renderer))
         (setup-wine-environment wrapper name "dxgi=n,b" #f)
         (check-equal? (getenv "RENDERER") name)
         (check-equal? (getenv "GAME_LAUNCHER_USE_ROSETTA") "0")
         (check-equal? (getenv "WINEDLLOVERRIDES") "dxgi=n,b")))))

  (test-case "invalid renderer types are not silently formatted as text"
    (with-fixture-environment
     (lambda ()
       (for ([renderer (list #f 42 '(d3dmetal))])
         (check-exn exn:fail:contract?
                    (lambda () (build-wine-invocation wrapper renderer)))
         (check-exn exn:fail:contract?
                    (lambda () (setup-wine-environment wrapper renderer)))))))

  (test-case "Ender Magnolia JSON record reaches both Wine boundaries"
    (define g (hash-ref (read-library seed-path) 'endermagnolia))
    (check-eq? (game-platform g) 'steam-wine)
    (check-eq? (game-renderer g) 'd3dmetal)
    (check-equal? (game-id g) 2725260)
    (define cmd (build-wine-invocation wrapper (game-renderer g)
                                       (game-dll-overrides g) (game-rosetta-x87? g)))
    (check-true (string-contains? cmd "RENDERER='d3dmetal' "))
    (with-fixture-environment
     (lambda ()
       (setup-wine-environment wrapper (game-renderer g)
                               (game-dll-overrides g) (game-rosetta-x87? g))
       (check-equal? (getenv "RENDERER") "d3dmetal"))))

  (test-case "all shipped Wine records reach command and environment boundaries"
    (with-fixture-environment
     (lambda ()
       (for ([(alias g) (in-hash (read-library seed-path))]
             #:when (and (game-wrapper g)
                         (memq (game-platform g)
                               '(steam-wine direct epic-wine epic gog-wine amazon))))
         (with-check-info (['alias alias])
           (check-true (symbol? (game-renderer g)))
           (define cmd (build-wine-invocation wrapper (game-renderer g)
                                              (game-dll-overrides g) (game-rosetta-x87? g)))
           (check-true (string-contains? cmd (format "RENDERER='~a' " (game-renderer g))))
           (setup-wine-environment wrapper (game-renderer g)
                                   (game-dll-overrides g) (game-rosetta-x87? g))
           (check-equal? (getenv "RENDERER") (symbol->string (game-renderer g)))))))))
