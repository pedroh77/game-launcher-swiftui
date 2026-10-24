#lang racket
(require rackunit (submod "../focus.rkt" test-support))

(define game-name "Return to Monkey Island")
(define runner "/Users/pedro/Applications/Jogos/Return to Monkey Island.app/Contents/MacOS/GameRunner")
(define backend "/Users/pedro/Applications/Jogos/Return to Monkey Island.app/Contents/Resources/Backend/")
(define executable "/Users/pedro/Library/Application Support/Steam/steamapps/common/Return to Monkey Island/Return to Monkey Island.app/Contents/MacOS/Return to Monkey Island")

(module+ test
  (test-case "the real native executable matches, including paths with spaces"
    (check-true (process-command-matches? game-name executable))
    (check-true (process-command-matches? (string-downcase game-name) executable)))
  (test-case "standalone launcher and its backend do not match the game"
    (for ([command (list runner (string-append runner " -psn_0_123")
                         (string-append "/bin/sh " backend "play rtmi")
                         (string-append "/Applications/Racket v9.3/bin/racket " backend "main.rkt rtmi"))])
      (check-false (process-command-matches? game-name command))))
  (test-case "a running launcher cannot prevent detection of game exit"
    (parameterize ([current-process-commands (lambda () (list runner executable))])
      (check-true (process-running? game-name)))
    (parameterize ([current-process-commands (lambda () (list runner))])
      (check-false (process-running? game-name))
      (check-false (process-running? ""))))
  (test-case "Wine executable monitoring and wrapper exclusions are preserved"
    (check-true (process-command-matches? "steam.exe" "/wine/bin/wine64 C:/Steam/steam.exe"))
    (check-true (process-command-matches? "Game.exe" "/wine/bin/wine64 C:/Games/Game.exe"))
    (check-false (process-command-matches? "Game.exe" "pwsh.exe -File C:/Scripts/steam_runner.ps1 -ProcessName Game.exe")))
  (test-case "process names are literal, including dots and regex punctuation"
    (check-true (process-command-matches? "Game (Mac).exe" "/Games/Game (Mac).exe"))
    (check-false (process-command-matches? "Game.exe" "/Games/GameXexe"))
    (check-false (process-command-matches? "$(echo test)" "/Games/test"))))
