#lang racket
(require rackunit racket/runtime-path
         "../library.rkt" "../racket-export.rkt")
(define-runtime-path types-path "../types.rkt")
(define-runtime-path seed-path "../games.seed.json")

(define (roundtrip games check)
  (define dir (make-temporary-file "racket-export-~a" 'directory))
  (dynamic-wind
   void
   (lambda ()
     (copy-file types-path (build-path dir "types.rkt"))
     (define output (build-path dir "games.rkt"))
     (write-racket-library games output)
     ;; A fresh namespace loads the original constructor next to the export.
     (parameterize ([current-namespace (make-base-namespace)])
       (define loaded (dynamic-require output 'GAMES))
       ;; Legacy CLI clients import games.rkt alone for both data and types.
       (for ([name '(game game-record game-record? game-title game-platform
                         game-id game-exe-name game-hidpi? game-blackbars?
                         game-renderer game-rosetta-x87? game-wrapper
                         game-dll-overrides game-game-dir game-save-dir
                         game-ps1-script game-focus-mode game-focus-coords)])
         (check-eq? (dynamic-require output name)
                    (dynamic-require (build-path dir "types.rkt") name)))
       (check loaded (lambda (name) (dynamic-require (build-path dir "types.rkt") name))))
     (define before (file->bytes output))
     (check-exn exn:fail:filesystem? (lambda () (write-racket-library games output)))
     (check-equal? (file->bytes output) before))
   (lambda () (delete-directory/files dir))))

(module+ test
  (test-case "all 118 games survive an independently loaded legacy module"
    (define games (read-library seed-path))
    (roundtrip games
     (lambda (loaded accessor)
       (check-equal? (hash-count loaded) 118)
       (for ([(alias original) (in-hash games)])
         (define exported (hash-ref loaded alias))
         (for ([name '(game-title game-platform game-id game-exe-name game-blackbars?
                                 game-renderer game-rosetta-x87? game-wrapper game-dll-overrides
                                 game-game-dir game-save-dir game-ps1-script game-focus-mode game-focus-coords)]
               [get (list game-title game-platform game-id game-exe-name game-blackbars?
                          game-renderer game-rosetta-x87? game-wrapper game-dll-overrides
                          game-game-dir game-save-dir game-ps1-script game-focus-mode game-focus-coords)])
           (check-equal? ((accessor name) exported) (get original) (format "~a: ~a" alias name)))))))
  (test-case "new profile is explicit; symbols and text are safely written"
    (define alias (string->symbol "123"))
    (roundtrip (hash alias (game "Ação e coração" 'direct "path with spaces" "game.exe"
                                #:hidpi? '2048x1280 #:focus-mode #f #:wrapper #f))
     (lambda (loaded accessor)
       (define g (hash-ref loaded alias))
       (check-equal? ((accessor 'game-hidpi?) g) '(2048 1280 1 2))
       (check-equal? ((accessor 'game-title) g) "Ação e coração")
       (check-false ((accessor 'game-focus-mode) g))
       (check-false ((accessor 'game-wrapper) g)))))
  (test-case "empty libraries load"
    (roundtrip (hash) (lambda (loaded _) (check-equal? (hash-count loaded) 0))))
  (test-case "procedure hooks cannot be serialized as code"
    (check-exn exn:fail? (lambda () (games->racket (hash 'custom (game "Custom" 'direct "id" "exe" #:focus-mode void)))))))
