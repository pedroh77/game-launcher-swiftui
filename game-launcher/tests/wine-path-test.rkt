#lang racket
(require rackunit "../wine.rkt" "../config.rkt")
(module+ test
  (test-case "absolute app paths keep their leading slash"
    (check-equal? (resolve-wrapper-path "/Users/test/Applications/My Wrapper.app")
                  "/Users/test/Applications/My Wrapper.app/Contents"))
  (test-case "absolute Contents paths are not extended again"
    (check-equal? (resolve-wrapper-path "/Applications/Steam_SK.app/Contents")
                  "/Applications/Steam_SK.app/Contents"))
  (test-case "trailing slashes are normalized on app and Contents paths"
    (check-equal? (resolve-wrapper-path "/Applications/Steam_SK.app/")
                  "/Applications/Steam_SK.app/Contents")
    (check-equal? (resolve-wrapper-path "/Applications/Steam_SK.app/Contents/")
                  "/Applications/Steam_SK.app/Contents"))
  (test-case "short wrapper names retain the legacy Applications base"
    (define expected (path->string (build-path APPLICATIONS-DIR "Steam_SK.app" "Contents")))
    (for ([name '("Steam_SK.app" "Steam_SK.app/" "Steam_SK.app/Contents" "Steam_SK.app/Contents/")])
      (check-equal? (resolve-wrapper-path name) expected))))
