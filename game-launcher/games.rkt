#lang racket
;; games.rkt - Banco de dados declarativo completo de todos os jogos em ~/bin/libexec
(require "types.rkt"
         "focus.rkt")
(provide (all-defined-out)
         (all-from-out "types.rkt"))

;; ============================================================
;; BANCO DE DADOS DE JOGOS
;; ============================================================
(define GAMES
  (hash
   ;; --- Afterimage (launch_afterimage.sh) ---
   'afterimage
   (game "Afterimage" 'steam-wine 1701520 "Afterimage-Win64-Shipping.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- AI: The Somnium Files ---
   'somnium
   (game "AI: The Somnium Files" 'steam-wine 948740 "AI_TheSomniumFiles.exe"
         #:renderer 'dxmt
         #:wrapper "Steam_SK.app"
         #:blackbars? #t
         #:dll-overrides "winhttp=n,b"
         #:focus-mode 6
         #:focus-coords "1919,1079")

   ;; --- Another Metroid 2 Remake (launch_am2r.sh) ---
   'am2r
   (game "Another Metroid 2 Remake" 'direct "AM2R.exe" "AM2R.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "d3d9=n,b"
         #:focus-mode #f)

   ;; --- Asleep (launch_asleep.sh) ---
   'asleep
   (game "Asleep" 'steam-mac 1583850 "Asleep"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Axiom Verge 2 (launch_axiom2.sh) ---
   'axiom2
   (game "Axiom Verge 2" 'steam-wine 946030 "AxiomVerge2.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Beacon Pines (launch_beaconpines.sh) ---
   'beaconpines
   (game "Beacon Pines" 'epic-wine "5e40f77f7e934af181110e88fdb9fca8" "Beacon Pines.exe"
         #:renderer 'dxmt
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- BioShock 2 Remastered (launch_bioshock2.sh) ---
   'bioshock2
   (game "BioShock 2 Remastered" 'steam-mac 409720 "BioShock"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- BioShock Infinite (launch_bioshock3.sh) ---
   'bioshock3
   (game "BioShock Infinite" 'steam-wine 8870 "BioShockInfinite.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Blasphemous (launch_blas.sh) ---
   'blas
   (game "Blasphemous" 'steam-wine 774361 "Blasphemous.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi,d3d11=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Blasphemous 2 (launch_blas2.sh) ---
   'blas2
   (game "Blasphemous 2" 'steam-wine 2114740 "Blasphemous 2.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Bō: Path of the Teal Lotus (launch_bo.sh) ---
   'bo
   (game "Bō: Path of the Teal Lotus" 'gog-wine "1882554410" "Bo.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:game-dir "$WRAPPER/SharedSupport/prefix/drive_c/Program Files (x86)/GOG Galaxy/Games/Bō Path of the Teal Lotus"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Boosteroid (launch_boosteroid.sh) ---
   'boosteroid
   (game "Boosteroid" 'steam-wine "" "pwsh.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Burnhouse Lane (launch_burnhouselane.sh) ---
   'burnhouselane
   (game "Burnhouse Lane" 'steam-wine 1846460 "BurnhouseLane.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:blackbars? #t
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Carrion (Mac) (launch_carrion.sh) ---
   'carrion
   (game "Carrion (Mac)" 'steam-mac 953490 "Carrion"
         #:focus-mode #f)

   ;; --- Carrion (Wine) (launch_carrionwin.sh) ---
   'carrionwin
   (game "Carrion (Wine)" 'steam-wine 953490 "Carrion.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "opengl32=n,b"
         #:focus-mode 2
         #:focus-coords "2083,1233")

   ;; --- Coffee Talk Episode 2 (launch_coffeetalk2.sh) ---
   'coffeetalk2
   (game "Coffee Talk Episode 2" 'steam-mac 1663220 "CTHB"
         #:focus-mode #f)

   ;; --- The Coma 2: Vicious Sisters (launch_coma3.sh) ---
   'coma3
   (game "The Coma 2: Vicious Sisters" 'direct "TheComa3.exe" "TheComa3.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- CrossCode (launch_crosscode.sh) ---
   'crosscode
   (game "CrossCode" 'steam-wine 368340 "CrossCode.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:blackbars? #t
         #:focus-mode 2
         #:focus-coords "2083,1233")

   ;; --- Crow Country (launch_crowcountry.sh) ---
   'crowcountry
   (game "Crow Country" 'steam-wine 1996010 "Crow Country.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Dark Devotion (launch_darkdevotion.sh) ---
   'darkdevotion
   (game "Dark Devotion" 'steam-wine 718590 "DarkDevotion.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "d3d9=n,b;d3d11=d"
         #:focus-mode #f)

   ;; --- The Darkside Detective: A Fumble in the Dark (launch_darkside2.sh) ---
   'darkside2
   (game "The Darkside Detective: A Fumble in the Dark" 'epic-mac "be0f81a12c8c462b98ffae5813f2dcc8" "The Darkside Detective: A Fumble in the Dark"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Dark Souls: Remastered (launch_darksouls.sh) ---
   'darksouls
   (game "Dark Souls: Remastered" 'direct "DarkSoulsRemastered.exe" "DarkSoulsRemastered.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "2083,1233")

   ;; --- Dead Cells (launch_deadcells.sh) ---
   'deadcells
   (game "Dead Cells" 'steam-wine 588650 "deadcells.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "d3d11,dinput8,xinput1_3,xinput1_4,SDL2=n,b"
         #:focus-mode 2
         #:focus-coords "581,484")

   ;; --- Deadly Premonition 2 (launch_deadlypremonition2.sh) ---
   'deadlypremonition2
   (game "Deadly Premonition 2" 'steam-wine 1271100 "DeadlyPremonition2.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:dll-overrides "winhttp=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Death's Door (launch_deathsdoor.sh) ---
   'deathsdoor
   (game "Death's Door" 'epic-wine "65d73e3be8824829b5b788bd849b6559" "DeathsDoor.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Death's Gambit: Afterlife (launch_deathsg.sh) ---
   'deathsg
   (game "Death's Gambit: Afterlife" 'steam-wine 356650 "deathsgambit397.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Record of Lodoss War: Deedlit in Wonder Labyrinth (launch_deedlit.sh) ---
   'deedlit
   (game "Record of Lodoss War: Deedlit in Wonder Labyrinth" 'steam-wine 1203630 "Deedlit in Wonder Labyrinth.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Dexter Stardust: Adventures in Outer Space (launch_dexterstardust.sh) ---
   'dexterstardust
   (game "Dexter Stardust: Adventures in Outer Space" 'amazon "amzn1.adg.product.0d9fd292-f386-406f-895b-a9385d3dfcb5" "Dexter Stardust.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:game-dir "$WRAPPER/SharedSupport/prefix/drive_c/Games/Amazon/Dexter Stardust Adventures in Outer Space"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Disco Elysium (launch_discoelysium.sh) ---
   'discoelysium
   (game "Disco Elysium" 'steam-mac 632470 "Disco"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Downfall (launch_downfall.sh) ---
   'downfall
   (game "Downfall" 'direct "Downfall.exe" "Downfall.exe"
         #:renderer 'dxmt
         #:wrapper "Steam_SK.app"
         #:dll-overrides "d3d9=n,b"
         #:game-dir "/Users/pedro/Applications/Steam_SK.app/Contents/SharedSupport/prefix/drive_c/downfall"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- DreadOut (Wine) (launch_dreadout.sh) ---
   'dreadout
   (game "DreadOut (Wine)" 'steam-wine 269790 "dreadout.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:dll-overrides "mmdevapi=b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- DreadOut (Mac) (launch_dreadout_mac.sh) ---
   'dreadout_mac
   (game "DreadOut (Mac)" 'steam-mac 269790 "dreadout"
         #:focus-mode #f)

   ;; --- DREDGE (Mac) (launch_dredge.sh) ---
   'dredge
   (game "DREDGE (Mac)" 'steam-mac 0 "DREDGE"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- DREDGE (Wine) (launch_dredgewin.sh) ---
   'dredgewin
   (game "DREDGE (Wine)" 'direct "GOGWrapper.exe" "GOGWrapper.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Dark Souls: Prepare to Die Edition (launch_dsptde.sh) ---
   'dsptde
   (game "Dark Souls: Prepare to Die Edition" 'steam-wine 211420 "DARKSOULS.exe"
         #:renderer 'mtld3d
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Else Heart.Break() (launch_elseheartbreak.sh) ---
   'elseheartbreak
   (game "Else Heart.Break()" 'steam-wine 400110 "ElseHeartbreak.exe"
         #:renderer 'mtld3d
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Ender Magnolia (launch_endermagnolia.sh) ---
   'endermagnolia
   (game "Ender Magnolia" 'steam-wine 2725260 "EnderMagnoliaSteam-Win64-Shipping.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Eternights (launch_eternights.sh) ---
   'eternights
   (game "Eternights" 'epic-wine "6ee8fe4d83fe49e49cbb79741616ec3b" "Eternights.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Etrian Odyssey III HD (launch_etrian3.sh) ---
   'etrian3
   (game "Etrian Odyssey III HD" 'steam-wine 1810820 "Etrian Odyssey 3.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Fallout: New Vegas (launch_falloutnv.sh) ---
   'falloutnv
   (game "Fallout: New Vegas" 'steam-wine 22380 "FalloutNV.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Fear the Spotlight (launch_fearthespotlight.sh) ---
   'fearthespotlight
   (game "Fear the Spotlight" 'steam-mac 1959390 "Fear"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- FEZ (launch_fez.sh) ---
   'fez
   (game "FEZ" 'steam-mac 224760 "FEZ"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- GOG Galaxy (HiDPI) (launch_galaxy.sh) ---
   'galaxy
   (game "GOG Galaxy (HiDPI)" 'direct "GOG Galaxy (HiDPI)" "GOG Galaxy (HiDPI)"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Gato Roboto (launch_gatoroboto.sh) ---
   'gatoroboto
   (game "Gato Roboto" 'gog-wine "1727534143" "GatoRoboto.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dxgi=n,b"
         #:game-dir "$WRAPPER/SharedSupport/prefix/drive_c/Program Files (x86)/GOG Galaxy/Games/Gato Roboto"
         #:save-dir "$WRAPPER/SharedSupport/prefix/drive_c/users/Sikarugir/AppData/Local/GatoRoboto_patch_1_1"
         #:focus-mode #f)

   ;; --- Gods Will Be Watching (launch_gods.sh) ---
   'gods
   (game "Gods Will Be Watching" 'steam-wine 274290 "gwbw.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Goetia (launch_goetia.sh) ---
   'goetia
   (game "Goetia" 'steam-mac 421740 "goetia"
         #:focus-mode #f)

   ;; --- GRIME (launch_grime.sh) ---
   'grime
   (game "GRIME" 'steam-mac 1123050 "GRIME"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- GRIS (launch_gris.sh) ---
   'gris
   (game "GRIS" 'steam-mac 683320 "GRIS"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Hades (launch_hades.sh) ---
   'hades
   (game "Hades" 'steam-mac 1145360 "Game.macOS"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Heartworm (launch_heartworm.sh) ---
   'heartworm
   (game "Heartworm" 'steam-wine 1257030 "Heartworm.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Hollow Knight (launch_hollowknight.sh) ---
   'hollowknight
   (game "Hollow Knight" 'steam-mac 0 "Hollow"
         #:focus-mode #f)

   ;; --- Hyper Light Drifter (launch_hyperlight.sh) ---
   'hyperlight
   (game "Hyper Light Drifter" 'epic-wine "Parakeet" "HyperLightDrifter.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1430,844")

   ;; --- ICEY (launch_icey.sh) ---
   'icey
   (game "ICEY" 'steam-mac 553640 "ICEY"
         #:focus-mode #f)

   ;; --- Katawa Shoujo (launch_katawa.sh) ---
   'katawa
   (game "Katawa Shoujo" 'steam-mac 3068300 "Katawa"
         #:focus-mode #f)

   ;; --- Kathy Rain Director's Cut (launch_kathyraindc.sh) ---
   'kathyraindc
   (game "Kathy Rain Director's Cut" 'gog-wine "2036622572" "KathyRainDirectorsCut.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dxgi=n,b"
         #:game-dir "$WRAPPER/SharedSupport/prefix/drive_c/Program Files (x86)/GOG Galaxy/Games/Kathy Rain Director’s Cut"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Kentucky Route Zero (launch_kentucky.sh) ---
   'kentucky
   (game "Kentucky Route Zero" 'steam-mac 231200 "KentuckyRouteZero"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Lacuna (launch_lacuna.sh) ---
   'lacuna
   (game "Lacuna" 'steam-wine 1364100 "Lacuna.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- La-Mulana 2 (launch_lamulana2.sh) ---
   'lamulana2
   (game "La-Mulana 2" 'steam-mac 835430 "La-Mulana"
         #:focus-mode #f)

   ;; --- Layers of Fear (launch_layersoffear.sh) ---
   'layersoffear
   (game "Layers of Fear" 'steam-mac 1946700 "LayersOfFear-Mac-Shipping"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Life is Strange (launch_lifeisstrange.sh) ---
   'lifeisstrange
   (game "Life is Strange" 'steam-mac 319630 "Life"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- The Long Dark (launch_longdark.sh) ---
   'longdark
   (game "The Long Dark" 'steam-mac 305620 "tld"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- The Messenger (launch_messenger.sh) ---
   'messenger
   (game "The Messenger" 'steam-wine 764790 "TheMessenger.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Milkmaid of the Milky Way (launch_milkmaid.sh) ---
   'milkmaid
   (game "Milkmaid of the Milky Way" 'steam-wine 544970 "milkmaid.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Moonlit Farewell (launch_moonlit.sh) ---
   'moonlit
   (game "Moonlit Farewell" 'steam-wine 1747760 "MomodoraMoonlitFarewell.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Mutazione (launch_mutazione.sh) ---
   'mutazione
   (game "Mutazione" 'steam-mac 0 "Mutazione"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- NieR:Automata (launch_nierautomata.sh) ---
   'nierautomata
   (game "NieR:Automata" 'steam-wine 524220 "NieRAutomata.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi,d3d11=n,b"
         #:focus-mode 2
         #:focus-coords "418,458")

   ;; --- NieR:Automata (Alt) (launch_nierautomata2.sh) ---
   'nierautomata2
   (game "NieR:Automata (Alt)" 'steam-wine 524220 "NieRAutomata.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:focus-mode 2
         #:focus-coords "418,458")

   ;; --- Nine Sols (launch_ninesols.sh) ---
   'ninesols
   (game "Nine Sols" 'steam-mac 1809540 "NineSols"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Night in the Woods (launch_nitw.sh) ---
   'nitw
   (game "Night in the Woods" 'steam-mac 0 "Night in the Woods"
         #:focus-mode #f)

   ;; --- Oceanhorn: Monster of Uncharted Seas (launch_oceanhorn.sh) ---
   'oceanhorn
   (game "Oceanhorn: Monster of Uncharted Seas" 'steam-mac 339200 "oceanhornosx-steam"
         #:focus-mode #f)

   ;; --- Ori and the Blind Forest: Definitive Edition (launch_oribf.sh) ---
   'oribf
   (game "Ori and the Blind Forest: Definitive Edition" 'steam-wine 387290 "oriDE.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:dll-overrides "mmdevapi,xaudio2_7=b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Outer Wilds (launch_outerwilds.sh) ---
   'outerwilds
   (game "Outer Wilds" 'steam-wine 753640 "OuterWilds.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Outlast (launch_outlast.sh) ---
   'outlast
   (game "Outlast" 'steam-mac 238320 "OLGame"
         #:focus-mode #f)

   ;; --- Owlboy (Mac) (launch_owlboy.sh) ---
   'owlboy
   (game "Owlboy (Mac)" 'steam-mac 115800 "Owlboy"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Owlboy (Wine) (launch_owlboywin.sh) ---
   'owlboywin
   (game "Owlboy (Wine)" 'steam-wine 115800 "Owlboy.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Pathologic Classic HD (launch_pathologic1.sh) ---
   'pathologic1
   (game "Pathologic Classic HD" 'steam-wine 384110 "Game.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "2083,1233")

   ;; --- Phoenotopia: Awakening (launch_phoenotopia.sh) ---
   'phoenotopia
   (game "Phoenotopia: Awakening" 'gog-mac "1758100348" "Phoenotopia: Awakening"
         #:game-dir "/Applications/Phoenotopia Awakening.app"
         #:save-dir "$HOME/Library/Application Support/unity.CapeCosmic.PhoenotopiaAwakening"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Prince of Persia: The Lost Crown (launch_princeof.sh) ---
   'princeof
   (game "Prince of Persia: The Lost Crown" 'steam-wine 2751000 "TheLostCrown.exe"
         #:renderer 'd3dmetal
         #:wrapper "The Lost Crown.app"
         #:dll-overrides "winhttp=n,b"
         #:ps1-script "princeof.ps1"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Psychonauts 2 (Wine) (launch_psychonauts2.sh) ---
   'psychonauts2
   (game "Psychonauts 2 (Wine)" 'steam-wine 607080 "Psychonauts2-Win64-Shipping.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode #f)

   ;; --- Psychonauts 2 (Mac) (launch_psychonauts2mac.sh) ---
   'psychonauts2mac
   (game "Psychonauts 2 (Mac)" 'steam-mac 607080 "Psychonauts2-Mac-Shipping"
         #:focus-mode #f)

   ;; --- Rabi-Ribi (launch_rabiribi.sh) ---
   'rabiribi
   (game "Rabi-Ribi" 'steam-wine 400910 "rabiribi.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Rain World (launch_rainw.sh) ---
   'rainw
   (game "Rain World" 'steam-wine 312520 "RainWorld.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- realMyst: Masterpiece Edition (launch_realmyst.sh) ---
   'realmyst
   (game "realMyst: Masterpiece Edition" 'steam-mac 244430 "realMyst"
         #:focus-mode #f)

   ;; --- Resident Evil HD Remaster ---
   'residentevil
   (game "Resident Evil HD Remaster" 'steam-wine 304240 "bhd.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Return to Monkey Island ---
   'rtmi
   (game "Return to Monkey Island" 'steam-mac 2060130 "Return to Monkey Island"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Shantae: Risky's Revenge (launch_risky.sh) ---
   'risky
   (game "Shantae: Risky's Revenge" 'steam-wine 277890 "RiskysRevenge.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "d3d9=n,b"
         #:hidpi? #f
         #:focus-mode 2
         #:focus-coords "1152,682")

   ;; --- SIGNALIS ---
   'signalis
   (game "SIGNALIS" 'steam-wine 1262350 "SIGNALIS.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 8
         #:focus-coords "1919,1079")

   ;; --- Bloodstained: Ritual of the Night (launch_rotn.sh) ---
   'rotn
   (game "Bloodstained: Ritual of the Night" 'steam-wine 692850 "BloodstainedRotN-Win64-Shipping.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:ps1-script "rotn.ps1"
         #:hidpi? '1680x1050
         #:focus-mode #f)

   ;; --- Momodora: Reverie Under the Moonlight (launch_rutm.sh) ---
   'rutm
   (game "Momodora: Reverie Under the Moonlight" 'steam-wine 428550 "MomodoraRUtM.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_SK.app"
         #:dll-overrides "d3d9=n,b"
         #:hidpi? '1680x1050
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Sally Face (launch_sallyface.sh) ---
   'sallyface
   (game "Sally Face" 'gog-wine "1158284393" "Sally Face.exe"
         #:renderer 'dxmt
         #:wrapper "Steam_SK.app"
         #:game-dir "$WRAPPER/SharedSupport/prefix/drive_c/Games/GOG/Sally Face"
         #:save-dir "$WRAPPER/SharedSupport/prefix/drive_c/users/Sikarugir/AppData/LocalLow/Steve Gabry/Sally Face"
         #:focus-mode #f)

   ;; --- Salt and Sanctuary (launch_saltsanctuary.sh) ---
   'saltsanctuary
   (game "Salt and Sanctuary" 'steam-mac 283640 "Salt"
         #:focus-mode #f)

   ;; --- Saturnalia (launch_saturnalia.sh) ---
   'saturnalia
   (game "Saturnalia" 'epic-mac "Cobia" "Saturnalia"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Shantae and the Pirate's Curse (launch_shantaecurse.sh) ---
   'shantaecurse
   (game "Shantae and the Pirate's Curse" 'steam-wine 345820 "ShantaeCurse.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dxgi=n,b"
         #:hidpi? '1680x1050
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Hollow Knight: Silksong (launch_silksong.sh) ---
   'silksong
   (game "Hollow Knight: Silksong" 'steam-mac 0 "Hollow"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Skullgirls 2nd Encore (launch_skullgirls.sh) ---
   'skullgirls
   (game "Skullgirls 2nd Encore" 'steam-mac 245170 "Skullgirls"
         #:focus-mode #f)

   ;; --- Subnautica: Below Zero (launch_snbelowzero.sh) ---
   'snbelowzero
   (game "Subnautica: Below Zero" 'steam-wine 848450 "SubnauticaZero.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- AI: The Somnium Files (launch_somnium.sh) ---
   ;'somnium
   ;(game "AI: The Somnium Files" 'steam-wine 948740 "AI_TheSomniumFiles.exe"
   ;      #:renderer 'dxmt
   ;      #:wrapper "Steam_SK.app"
   ;      #:dll-overrides "winhttp=n,b"
   ;      #:ps1-script "somnium.ps1"
   ;      #:hidpi? #t
   ;      #:blackbars? #t
   ;      #:focus-mode
   ;      (λ ()
   ;        (wait-for-process "steamwebhelper.exe")
   ;        (wait-for-process "Launcher.exe")
   ;        (sleep 6)
   ;        (click "1241,941" 2)
   ;        (sleep 10)
   ;        (click "1919,1079" 2)
   ;        (hide-cursor)))

   ;; --- Shadow of the Colossus (launch_sotc.sh) ---
   'sotc
   (game "Shadow of the Colossus" 'direct "GOGWrapper.exe" "GOGWrapper.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "2083,1233")

   ;; --- SquareCells (launch_squarecells.sh) ---
   'squarecells
   (game "SquareCells" 'steam-mac 416770 "SquareCells"
         #:focus-mode #f)

   ;; --- Stardew Valley (launch_stardew.sh) ---
   'stardew
   (game "Stardew Valley" 'steam-mac 413150 "Stardew"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- STASIS (launch_stasis.sh) ---
   'stasis
   (game "STASIS" 'steam-mac 0 "Stasis"
         #:focus-mode #f)

   ;; --- Steam (HiDPI) (launch_steam.sh) ---
   'steam
   (game "Steam (HiDPI)" 'direct "Steam (HiDPI)" "Steam (HiDPI)"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Stray (launch_stray.sh) ---
   'stray
   (game "Stray" 'steam-wine 1332010 "Stray-Mac-Shipping"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dinput8=n,b"
         #:focus-mode #f)

   ;; --- Subnautica (Mac) (launch_subnautica.sh) ---
   'subnautica
   (game "Subnautica (Mac)" 'steam-mac 264710 "Subnautica"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Subnautica (Wine) (launch_subnauticawin.sh) ---
   'subnauticawin
   (game "Subnautica (Wine)" 'steam-wine 264710 "Subnautica.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Sundered (launch_sundered.sh) ---
   'sundered
   (game "Sundered" 'gog-mac "1116941879" "Sundered"
         #:game-dir "/Applications/Sundered.app"
         #:focus-mode #f)

   ;; --- The Fall (Wine) (launch_thefall.sh) ---
   'thefall
   (game "The Fall (Wine)" 'steam-wine 290770 "TheFall.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- The Fall Part 2: Unbound (launch_thefall2.sh) ---
   'thefall2
   (game "The Fall Part 2: Unbound" 'direct "TheFallPart2Unbound.exe" "TheFallPart2Unbound.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- The Fall (Epic) (launch_thefallepic.sh) ---
   'thefallepic
   (game "The Fall (Epic)" 'direct "/Users/Shared/Epic Games/TheFall/TheFall.app/Contents/MacOS/The Fall" "The Fall"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- The House in Fata Morgana (launch_thifm.sh) ---
   'thifm
   (game "The House in Fata Morgana" 'direct "The House in Fata Morgana" "The House in Fata Morgana"
         #:renderer 'd3dmetal
         #:wrapper "Contents"
         #:focus-mode #f)

   ;; --- Tormented Souls (launch_tormentedsouls.sh) ---
   'tormentedsouls
   (game "Tormented Souls" 'direct "Tormented Souls" "Tormented Souls"
         #:renderer 'd3dmetal
         #:wrapper "Contents"
         #:hidpi? #f
         #:focus-mode #f)

   ;; --- Touhou Luna Nights (launch_touhou.sh) ---
   'touhou
   (game "Touhou Luna Nights" 'steam-wine 851100 "touhou_luna_nights.exe"
         #:renderer 'dxvk
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "d3d11=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Transistor (launch_transistor.sh) ---
   'transistor
   (game "Transistor" 'steam-mac 237930 "Transistor.bin.osx"
         #:focus-mode #f)

   ;; --- Tales of Vesperia: Definitive Edition (launch_vesperia.sh) ---
   'vesperia
   (game "Tales of Vesperia: Definitive Edition" 'steam-wine 738540 "TOV_DE.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:dll-overrides "dxgi=n,b"
         #:focus-mode #f)

   ;; --- The Witch's House MV (launch_witchshouse.sh) ---
   'witchshouse
   (game "The Witch's House MV" 'steam-wine 885810 "game.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:focus-mode 2
         #:focus-coords "377,128")

   ;; --- Withering Realms Demo ---
   'witheringrealmsdemo
   (game "Withering Realms Demo" 'steam-wine 4359820 "Withering Realms.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 6
         #:focus-coords "1919,1079")

   ;; --- Withering Rooms (launch_witheringrooms.sh) ---
   'witheringrooms
   (game "Withering Rooms" 'steam-wine 2006140 "Withering Rooms.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_SK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Ys VIII: Lacrimosa of DANA (launch_ys8.sh) ---
   'ys8
   (game "Ys VIII: Lacrimosa of DANA" 'steam-wine 579180 "ys8.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:dll-overrides "dinput8=n,b"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ;; --- Ys: Memories of Celceta (launch_yscelceta.sh) ---
   'yscelceta
   (game "Ys: Memories of Celceta" 'steam-wine 587110 "Ysc_dx11.exe"
         #:renderer 'd3dmetal
         #:wrapper "Steam_DXVK.app"
         #:focus-mode 2
         #:focus-coords "1919,1079")

   ))
