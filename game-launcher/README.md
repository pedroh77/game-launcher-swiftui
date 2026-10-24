# 🎮 Lançador de Jogos Universal em Racket

**0.3.2 Wine integration:** see `../GameLauncherApp/WINE-INTEGRATION.md`. The backend now owns `wine-launch.sh` and `wine-cleanup.sh`; keep them alongside wine.rkt (the launch adapter must be executable). It reads the live script selected by GAME_LAUNCHER_WINE_ENV, defaulting to ~/bin/libexec/wine_env.sh. The old external wine_x87.sh is no longer needed by this backend. Install the provided kill-wine-processes.sh for the existing play Cancel path.

Sistema modular de automação e lançamento de jogos para macOS (Nativo e Wine), consolidando dezenas de scripts shell em uma arquitetura declarativa, segura e reutilizável.

---

## 📁 Estrutura de Arquivos

```
~/bin/game-launcher/
├── config.rkt              # Constantes e caminhos de executáveis do sistema
├── display.rkt             # Gerenciamento de HiDPI (RDM), ponteiro e Blackbars
├── focus.rkt               # Automação assíncrona de foco e cursor (cliclick + Cursorcerer)
├── wine.rkt                # Configuração de variáveis de ambiente do Wine e renderers
├── games.rkt               # Banco de dados central com todos os jogos e aliases
├── main.rkt                # Ponto de entrada CLI e parser de argumentos
├── README.md               # Documentação do sistema
└── runners/
    ├── steam-mac.rkt       # Lançador para jogos nativos do Steam
    ├── steam-wine.rkt      # Lançador para jogos Steam no Wine via PowerShell
    ├── gog.rkt             # Lançador GOG via gogdl (comet + cloud save-sync)
    ├── epic.rkt            # Lançador Epic Games via legendary
    ├── amazon.rkt          # Lançador Amazon Games via nile
    └── direct.rkt          # Lançador de executáveis diretos (Wine ou Mac)
```

---

## 🚀 Como Usar via Terminal

O script auxiliar `~/bin/play` já está disponível no seu `PATH`:

```bash
# Listar todos os jogos cadastrados
play --list

# Consultar configurações de um jogo específico
play --info darksouls

# Lançar um jogo pelo alias
play darksouls
play hades
play gatoroboto
play somnium
```

---

## ➕ Como Adicionar um Novo Jogo

Abra `~/bin/game-launcher/games.rkt` e adicione uma entrada na tabela `GAMES`:

```racket
'novo-jogo
(game "Nome do Jogo" 'steam-wine 1234560 "Jogo.exe"
      #:renderer 'd3dmetal        ; 'd3dmetal | 'dxvk | 'dxmt | 'mtld3d | 'd9mt | 'none
      #:wrapper "Steam_SK.app"    ; Wrapper em ~/Applications
      #:hidpi? #t                 ; Alternar para 2560x1600 durante o jogo
      #:blackbars? #f             ; Ativar helper de barras pretas para jogos 16:9
      #:dll-overrides "dxgi=n,b"  ; Opcional: overrides de DLL
      #:focus-mode 6)             ; Delay de foco em segundos (ou #f para desativar)
```

---

## 🦅 Integração com Platypus

Para criar um ícone/app independente para um jogo usando o **Platypus**:

1. **Script Path**: Crie um script wrapper de 1 linha:
   ```bash
   #!/bin/dash
   exec /Users/pedro/bin/play <alias-do-jogo>
   ```
2. **Interface**: Escolha `None` (ou `Progress Bar` se preferir acompanhar os logs).
3. **Opção Compilada**:
   Você também pode compilar o executável binário do Racket com:
   ```bash
   raco exe -o ~/bin/game-launcher/play-bin ~/bin/game-launcher/main.rkt
   ```
   E no Platypus chamar diretamente:
   ```bash
   /Users/pedro/bin/game-launcher/play-bin <alias-do-jogo>
   ```

---

## 🛡️ Garantias de Limpeza (`dynamic-wind`)

O sistema utiliza `dynamic-wind` do Racket em todas as operações sensíveis:
- **Resolução de Tela e Mouse**: Sempre restaurados ao estado original (`1440x900`, escala `1x`), mesmo se o jogo ou o script forem interrompidos.
- **Helper de Barras Pretas (`blackbars`)**: Sempre finalizado no encerramento.
- **Sleep Prevention (`caffeinate`)**: Encerrado de forma segura no término.
- **Processos do Wine**: Limpeza automática via `wineserver -k` ou scripts `kill-steam-*.sh`.
