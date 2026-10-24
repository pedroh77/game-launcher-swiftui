#lang racket
;; Native display ownership contract v1. The app sets this only while it owns a
;; live display lease; direct Terminal/legacy launches leave it unset.
(require racket/string racket/match)
(provide native-display-state native-profile-matches?)

(define (native-display-state)
  (define value (getenv "GAME_LAUNCHER_NATIVE_DISPLAY"))
  (cond
    [(or (not value) (string=? value "")) 'legacy]
    [(string=? value "skip") 'skip]
    [(regexp-match? #px"^[1-9][0-9]*,[1-9][0-9]*,[12]$" value)
     (map string->number (string-split value ","))]
    [else (error 'native-display "Invalid native display owner contract; refusing to launch.")]))

(define (native-profile-matches? state width height scale)
  (match state
    [(list w h s) (and (= w width) (= h height) (= s scale))]
    [_ #f]))
