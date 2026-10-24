#lang racket
;; wine.rkt - Configuração de ambiente Wine, renderers gráficos, RosettaX87 e cleanup
(require racket/runtime-path
         racket/system
         racket/string
         racket/path
         "config.rkt")

(provide wine-launch-argument
         wine-launch-script
         resolve-wrapper-path
         setup-wine-environment
         get-wine-binary
         get-wine-exec-prefix
         get-pwsh-windows-path
         build-wine-invocation
         cleanup-wine)

;; live-wine-env-v1
(define-runtime-path wine-launch-script "wine-launch.sh")
(define-runtime-path wine-cleanup-script "wine-cleanup.sh")
(define (shell-quote value)
  (string-append "'" (string-replace value "'" "'\"'\"'") "'"))

(define wine-launch-argument (shell-quote (path->string wine-launch-script)))

;; Resolve o caminho completo de Contents do wrapper
(define (resolve-wrapper-path wrapper-name-or-path)
  ;; Preserve the leading slash of paths chosen by the GUI's file picker.
  (define clean (string-trim wrapper-name-or-path "/" #:left? #f))
  (define full
    (if (string-prefix? clean "/")
        clean
        (path->string (build-path APPLICATIONS-DIR clean))))
  (if (string-suffix? full "/Contents")
      full
      (format "~a/Contents" full)))

;; Localiza o executável correto do PowerShell dentro do prefixo Wine
(define (get-pwsh-windows-path wrapper-path)
  (define prefix-drive-c (format "~a/SharedSupport/prefix/drive_c" wrapper-path))
  (cond
    [(file-exists? (build-path prefix-drive-c "Program Files/PowerShell/7-preview/pwsh.exe"))
     "C:/Program Files/PowerShell/7-preview/pwsh.exe"]
    [(file-exists? (build-path prefix-drive-c "Program Files/PowerShell/7/pwsh.exe"))
     "C:/Program Files/PowerShell/7/pwsh.exe"]
    [(file-exists? (build-path prefix-drive-c "PowerShell-7/pwsh.exe"))
     "C:/PowerShell-7/pwsh.exe"]
    [else
     "pwsh.exe"]))

;; Game records use symbols; shell/environment boundaries require strings.
;; Retain string callers without coercing unrelated values into renderer names.
(define (renderer->string renderer)
  (cond [(symbol? renderer) (symbol->string renderer)]
        [(string? renderer) renderer]
        [else (raise-argument-error 'renderer->string "(or/c symbol? string?)" renderer)]))

;; Adapter sources the selected live wine_env.sh for every Wine invocation.
(define (build-wine-invocation wrapper-path renderer [dll-overrides #f] [rosetta? #t])
  (format "WRAPPER=~a RENDERER=~a GAME_LAUNCHER_USE_ROSETTA=~a ~a~a"
          (shell-quote wrapper-path) (shell-quote (renderer->string renderer)) (if rosetta? "1" "0")
          (if dll-overrides (format "WINEDLLOVERRIDES=~a " (shell-quote dll-overrides)) "")
          (shell-quote (path->string wine-launch-script))))

;; Prepara as variáveis de ambiente no processo atual
(define (setup-wine-environment wrapper-path renderer [dll-overrides #f] [rosetta? #t])
  (define wine-prefix (format "~a/SharedSupport/prefix" wrapper-path))
  (define wine-bin-dir (format "~a/SharedSupport/wine/bin" wrapper-path))
  (define home (path->string (find-system-path 'home-dir)))

  (unless (and (file-exists? wine-launch-script)
               (member 'execute (file-or-directory-permissions wine-launch-script)))
    (error 'wine "Bundled Wine adapter is missing or not executable: ~a" wine-launch-script))
  (define env-file (or (getenv "GAME_LAUNCHER_WINE_ENV")
                       (path->string (expand-user-path "~/bin/libexec/wine_env.sh"))))
  (unless (and (absolute-path? env-file) (file-exists? env-file))
    (error 'wine "Wine environment script missing or not absolute: ~a" env-file))
  (putenv "GAME_LAUNCHER_WINE_ENV" env-file)
  (putenv "RENDERER" (renderer->string renderer))
  (putenv "GAME_LAUNCHER_USE_ROSETTA" (if rosetta? "1" "0"))
  (when dll-overrides (putenv "WINEDLLOVERRIDES" dll-overrides))
  (putenv "WRAPPER" wrapper-path)
  (putenv "WINEPREFIX" wine-prefix)
  (putenv "PATH" (format "~a/bin:~a:~a" home wine-bin-dir (or (getenv "PATH") ""))))

;; Caminho do executável do Wine
(define (get-wine-binary wrapper-path)
  (format "~a/SharedSupport/wine/bin/wine" wrapper-path))

;; Retorna o prefixo de execução do Wine
(define (get-wine-exec-prefix wrapper-path [rosetta? #t])
  (define wine-bin (get-wine-binary wrapper-path))
  (if (and rosetta? (file-exists? ROSETTA-X87-LOADER))
      (list (path->string ROSETTA-X87-LOADER) wine-bin)
      (list wine-bin)))

;; Limpeza de processos Wine
(define (cleanup-wine wrapper-path)
  (printf "🧹 Limpando o prefixo Wine: ~a\n" wrapper-path)
  ;; Same dylib/environment repair as the supplied Terminal cleanup helper.
  ;; This targeted normal-exit path does not use the old Steam-specific scripts.
  (unless (system* "/bin/bash" wine-cleanup-script wrapper-path)
    (error 'cleanup-wine "Wine cleanup helper failed; see the output above.")))
