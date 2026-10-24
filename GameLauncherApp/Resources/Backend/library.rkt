#lang racket
;; Shared, versioned data for the CLI and the macOS editor.
(require json racket/runtime-path "types.rkt")
(provide load-games read-library jsexpr->games games->jsexpr
         default-library-path (all-from-out "types.rkt"))

(define-runtime-path legacy-games-path "games.rkt")
(define (default-library-path)
  (build-path (find-system-path 'home-dir) "Library" "Application Support"
              "Game Launcher" "games.json"))
(define platforms '("steam-mac" "steam-wine" "gog-mac" "gog-wine"
                              "epic-mac" "epic-wine" "epic" "amazon" "direct"))
(define renderers '("d3dmetal" "dxvk" "dxmt" "mtld3d" "d9mt" "none"))
(define display-modes '("off" "2560x1600" "2048x1280" "1680x1050" "1920x1200" "1280x800" "custom"))

(define (bad fmt . args) (apply error 'game-library fmt args))
(define (field h key pred description [default 'missing])
  (define value (hash-ref h key (lambda () default)))
  (unless (pred value) (bad "~a: expected ~a, got ~e" key description value))
  value)
(define (optional-string h key)
  (define v (hash-ref h key 'null))
  (cond [(eq? v 'null) #f] [(string? v) v]
        [else (bad "~a must be a string or null" key)]))
(define (finite-real? n) (and (real? n) (not (nan? n)) (not (infinite? n))))
;; JSON encoders may emit integral values as 1 or 1.0. Normalize fields that
;; must become exact integers before passing them to the existing runners.
(define (json-integer? n) (and (finite-real? n) (integer? n)))
(define (positive-json-integer? n) (and (json-integer? n) (> n 0)))
(define (safe-text! key value #:variables? [variables? #f])
  ;; Existing runners interpolate double-quoted shell strings. Only the two
  ;; established path placeholders may contain '$'; do not execute substitutions.
  (when value
    (define text
      (if variables? (regexp-replace #px"^\\$(?:WRAPPER|HOME)(?=/|$)" value "") value))
    (when (regexp-match? #px"[\"`$\\\\\r\n\u0000]" text)
      (bad "~a contains unsupported shell quoting/substitution characters" key))))

(define (json-game->record h)
  (unless (hash? h) (bad "each game must be an object"))
  (define alias (field h 'alias (lambda (s) (and (string? s) (regexp-match? #px"^[A-Za-z0-9][A-Za-z0-9_-]*$" s))) "an alias using letters, digits, _ or -"))
  (define title (field h 'title (lambda (s) (and (string? s) (non-empty-string? (string-trim s)))) "a nonempty title"))
  (define platform (field h 'platform (lambda (v) (member v platforms)) "a supported platform"))
  (define id-value (field h 'id (lambda (v) (or (string? v) (and (json-integer? v) (>= v 0)))) "a string or nonnegative integer"))
  (define raw-id (if (number? id-value) (inexact->exact id-value) id-value))
  (define id-text (~a raw-id))
  (when (and (member platform '("steam-mac" "steam-wine"))
             (not (regexp-match? #px"^[0-9]*$" id-text)))
    (bad "~a: Steam ID must contain only digits (legacy empty IDs are allowed)" alias))
  (define exe (field h 'exeName string? "a process/executable name"))
  (define renderer (field h 'renderer (lambda (v) (member v renderers)) "a supported renderer" "d3dmetal"))
  (define wrapper (optional-string h 'wrapper))
  (when (and (member platform '("steam-wine" "gog-wine" "epic-wine" "amazon"))
             (or (not wrapper) (string=? (string-trim wrapper) "")))
    (bad "~a: this runner requires a Wine wrapper" alias))
  (define display-mode (field h 'displayMode (lambda (v) (member v display-modes)) "a display profile" "2560x1600"))
  (define hidpi
    (cond [(equal? display-mode "off") #f]
          [(equal? display-mode "custom")
           (define p (field h 'customDisplay hash? "a custom display object"))
           (list (inexact->exact (field p 'width positive-json-integer? "a positive width"))
                 (inexact->exact (field p 'height positive-json-integer? "a positive height"))
                 (inexact->exact (field p 'scale (lambda (n) (and (json-integer? n) (or (= n 1) (= n 2)))) "RDM scale 1 or 2"))
                 (field p 'pointerScale (lambda (n) (and (finite-real? n) (> n 0))) "a positive pointer scale"))]
          [else (string->symbol display-mode)]))
  (define delay (hash-ref h 'focusDelay 'null))
  (unless (or (eq? delay 'null) (and (finite-real? delay) (>= delay 0)))
    (bad "~a: focusDelay must be null or a nonnegative number" alias))
  (define coords (optional-string h 'focusCoords))
  (when (and coords (not (regexp-match? #px"^-?[0-9]+,-?[0-9]+$" coords)))
    (bad "~a: focusCoords must be x,y (integer coordinates)" alias))
  (define dll (optional-string h 'dllOverrides))
  (define game-dir (optional-string h 'gameDir))
  (define save-dir (optional-string h 'saveDir))
  (define ps1 (optional-string h 'ps1Script))
  (for ([key '(title id exeName wrapper dllOverrides ps1Script)]
        [value (list title id-text exe wrapper dll ps1)])
    (safe-text! key value))
  (safe-text! 'gameDir game-dir #:variables? #t)
  (safe-text! 'saveDir save-dir #:variables? #t)
  (values (string->symbol alias)
          (game title (string->symbol platform) raw-id exe
                #:hidpi? hidpi
                #:blackbars? (field h 'blackbars boolean? "a boolean" #f)
                #:renderer (string->symbol renderer)
                #:rosetta-x87? (field h 'rosettaX87 boolean? "a boolean" #t)
                #:wrapper wrapper #:dll-overrides dll
                #:game-dir game-dir #:save-dir save-dir #:ps1-script ps1
                #:focus-mode (if (eq? delay 'null) #f delay)
                #:focus-coords coords)))

(define (jsexpr->games doc)
  (unless (hash? doc) (bad "library must be an object"))
  (define version (hash-ref doc 'schemaVersion #f))
  (unless (and (json-integer? version) (= version 1))
    (bad "unsupported schemaVersion; expected 1"))
  (define rows (field doc 'games list? "an array"))
  (for/fold ([games (hash)]) ([row (in-list rows)])
    (define-values (alias g) (json-game->record row))
    (when (hash-has-key? games alias) (bad "duplicate alias: ~a" alias))
    (hash-set games alias g)))

(define (read-library path)
  (call-with-input-file path
    (lambda (in)
      (define doc (read-json in))
      (unless (eof-object? (read-json in)) (bad "unexpected data after the JSON document"))
      (jsexpr->games doc))))

(define (load-games)
  (define override (getenv "GAME_LAUNCHER_LIBRARY"))
  (define path (if override (expand-user-path override) (default-library-path)))
  (cond [(file-exists? path) (read-library path)]
        [override (bad "configured library does not exist: ~a" path)]
        [else (dynamic-require legacy-games-path 'GAMES)]))

(define (nullable v) (if (eq? v #f) 'null v))
(define (games->jsexpr games)
  (hash 'schemaVersion 1
        'games
        (for/list ([alias (in-list (sort (hash-keys games) symbol<?))])
          (define g (hash-ref games alias))
          (define focus (game-focus-mode g))
          (when (procedure? focus)
            (bad "~a has a custom focus procedure; migration requires a named-hook implementation" alias))
          (define mode (game-hidpi? g))
          (define mode-name
            (cond [(not mode) "off"] [(or (eq? mode #t) (eq? mode 'default)) "2560x1600"]
                  [(symbol? mode) (symbol->string mode)] [(string? mode) mode]
                  [(list? mode) "custom"] [else (bad "unsupported display mode for ~a" alias)]))
          (define row
            (hash 'alias (symbol->string alias) 'title (game-title g)
                  'platform (symbol->string (game-platform g)) 'id (game-id g)
                  'exeName (game-exe-name g) 'displayMode mode-name
                  'blackbars (game-blackbars? g) 'renderer (symbol->string (game-renderer g))
                  'rosettaX87 (game-rosetta-x87? g) 'wrapper (nullable (game-wrapper g))
                  'dllOverrides (nullable (game-dll-overrides g))
                  'gameDir (nullable (game-game-dir g)) 'saveDir (nullable (game-save-dir g))
                  'ps1Script (nullable (game-ps1-script g))
                  'focusDelay (nullable focus) 'focusCoords (nullable (game-focus-coords g))))
          (if (list? mode)
              (hash-set row 'customDisplay
                        (match mode [(list w h s p) (hash 'width w 'height h 'scale s 'pointerScale p)]))
              row))))
