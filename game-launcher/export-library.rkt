#lang racket
;; Export only reads the legacy configuration. Refuse to overwrite an existing file.
(require json "library.rkt" (prefix-in legacy: "games.rkt"))
(module+ main
  (define args (current-command-line-arguments))
  (unless (= (vector-length args) 1)
    (error 'export-library "usage: racket export-library.rkt OUTPUT.json"))
  (define doc (games->jsexpr legacy:GAMES))
  (void (jsexpr->games doc)) ; validate the entire migration before writing
  (call-with-output-file (vector-ref args 0)
    (lambda (out) (write-json doc out) (newline out))
    #:exists 'error)
  (printf "Exported ~a games to ~a\n" (hash-count legacy:GAMES) (vector-ref args 0)))
