#lang racket
;; config.rkt - Constantes e caminhos globais do sistema de lançamento de jogos
(require racket/runtime-path)
(provide (all-defined-out))

(define-runtime-path config-dir ".")

;; ============================================================
;; UTILITÁRIOS DO SISTEMA MAC OS
;; ============================================================
(define RDM-PATH "/Applications/RDM.app/Contents/MacOS/RDM")
(define CLICLICK-PATH "/opt/homebrew/bin/cliclick")
(define BLACKBARS-PATH
  (cond
    [(getenv "GAME_LAUNCHER_BLACKBARS") (string->path (getenv "GAME_LAUNCHER_BLACKBARS"))]
    [(let ([bundled (build-path config-dir "blackbars")])
       (and (file-exists? bundled) bundled))]
    [(file-exists? (expand-user-path "~/bin/libexec/blackbars"))
     (expand-user-path "~/bin/libexec/blackbars")]
    [else (expand-user-path "~/bin/libexec/blackbars")]))
(define STEAM-MAC-BIN "/Applications/Steam.app/Contents/MacOS/steam_osx")
(define ACTIVATE-SETTINGS-BIN "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")

;; ============================================================
;; HEROIC / LAUNCHERS DE TERCEIROS
;; ============================================================
(define HEROIC-CONFIG-DIR (expand-user-path "~/Library/Application Support/heroic"))
(define HEROIC-APP-BIN-DIR "/Applications/Heroic.app/Contents/Resources/app.asar.unpacked/build/bin/arm64/darwin")

(define GOGDL-BIN (build-path HEROIC-APP-BIN-DIR "gogdl"))
(define LEGENDARY-BIN (build-path HEROIC-APP-BIN-DIR "legendary"))
(define NILE-BIN (build-path HEROIC-APP-BIN-DIR "nile"))

(define GOG-AUTH-FILE (build-path HEROIC-CONFIG-DIR "gog_store/auth.json"))
(define GOGDL-CONFIG-DIR (build-path HEROIC-CONFIG-DIR "gogdlConfig"))
(define LEGENDARY-CONFIG-DIR (build-path HEROIC-CONFIG-DIR "legendaryConfig/legendary"))
(define NILE-CONFIG-DIR (build-path HEROIC-CONFIG-DIR "nile_config"))

;; ============================================================
;; ROSETTA X87 JIT
;; ============================================================
(define ROSETTA-X87-LOADER
  (cond
    [(getenv "GAME_LAUNCHER_ROSETTA_LOADER") (string->path (getenv "GAME_LAUNCHER_ROSETTA_LOADER"))]
    [(let ([bundled (build-path config-dir "runtime_loader")])
       (and (file-exists? bundled) bundled))]
    [(file-exists? (expand-user-path "~/git/rosettax87_jit/build/bin/runtime_loader"))
     (expand-user-path "~/git/rosettax87_jit/build/bin/runtime_loader")]
    [else (expand-user-path "~/git/rosettax87_jit/build/bin/runtime_loader")]))

(define ROSETTA-X87-BIN-DIR
  (let ([loader ROSETTA-X87-LOADER])
    (cond
      [(and (path? loader) (file-exists? loader))
       (simplify-path (build-path loader 'up))]
      [else (expand-user-path "~/git/rosettax87_jit/build/bin")])))

;; ============================================================
;; WINE WRAPPERS BASE
;; ============================================================
(define APPLICATIONS-DIR (expand-user-path "~/Applications"))
(define DEFAULT-STEAM-SK-WRAPPER (build-path APPLICATIONS-DIR "Steam_SK.app/Contents"))
(define DEFAULT-STEAM-DXVK-WRAPPER (build-path APPLICATIONS-DIR "Steam_DXVK.app/Contents"))

;; Mapeamento de controle Switch Pro (padrão)
(define DEFAULT-SDL-GAMECONTROLLERCONFIG
  "0300d71f7e0500000920000001006803,*,a:b1,b:b0,back:b4,dpdown:b12,dpleft:b13,dpright:b14,dpup:b11,guide:b5,leftshoulder:b9,leftstick:b7,lefttrigger:a4,leftx:a0,lefty:a1,rightshoulder:b10,rightstick:b8,righttrigger:a5,rightx:a2,righty:a3,start:b6,x:b3,y:b2,misc1:b15,crc:1fd7,platform:Mac OS X")
