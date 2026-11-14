#Requires -Version 7
<#
.SYNOPSIS
    Limpeza periódica do C: — caches que voltam a crescer, sobras conhecidas e inicialização automática.

.DESCRIPTION
    Tudo aqui é seguro de rodar sempre: cada item checa se existe antes de apagar e
    nenhum programa instalado é removido. O que foi feito uma única vez (desinstalações,
    WSL etc.) está registrado no bloco "HISTÓRICO" no fim do arquivo.

    Fluxo: calcula o que vai ser apagado (sem admin), mostra o total, pede confirmação
    e só então abre o UAC para executar.

.PARAMETER Simular
    Só mostra o que seria apagado e quanto ocuparia, sem perguntar nem apagar nada.

.PARAMETER SemDism
    Pula a limpeza de componentes do Windows (DISM), que é a etapa mais demorada.

.PARAMETER Confirmado
    Executa direto, sem estimativa nem pergunta (usado internamente após o UAC;
    útil também para agendar).

.EXAMPLE
    pwsh -File limpeza-sistema.ps1            # estima, pergunta, executa como admin
    pwsh -File limpeza-sistema.ps1 -Simular   # só estima
#>
param(
    [switch]$Simular,
    [switch]$SemDism,
    [switch]$Confirmado,
    # Perfil do usuário capturado antes da elevação, para não limpar o perfil errado
    # caso o UAC peça credenciais de outra conta de administrador.
    [string]$Perfil = $env:USERPROFILE
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$Local   = Join-Path $Perfil 'AppData\Local'
$Roaming = Join-Path $Perfil 'AppData\Roaming'

# Modo da passada atual: $true = só mede, $false = apaga.
$script:Seco       = $true
$script:totalBytes = 0

function Get-Tamanho([string]$Path) {
    [long](Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
}

# Registra o item no total e imprime a linha (itens abaixo de 1 MB são omitidos).
function Registrar([long]$Bytes, [string]$Descricao) {
    $script:totalBytes += $Bytes
    if ($Bytes -ge 1MB) { "{0,9:N2} GB  {1}" -f ($Bytes / 1GB), $Descricao }
}

# Apaga o conteúdo da pasta (mantém a pasta). Arquivos em uso são ignorados.
function Limpar-Conteudo([string]$Path, [string]$Descricao) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Registrar (Get-Tamanho $Path) $Descricao
    if (-not $script:Seco) {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Apaga a pasta inteira.
function Remover-Pasta([string]$Path, [string]$Descricao) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Registrar (Get-Tamanho $Path) $Descricao
    if (-not $script:Seco) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue }
}

function Test-ReinicioPendente {
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
}

function Invoke-Limpeza {
    # ── 1. Caches de apps ───────────────────────────────────────────────────
    "== Caches de apps =="
    # Os apps precisam estar fechados para soltar os arquivos de cache.
    if (-not $script:Seco) { Get-Process Spotify, Stremio -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2 }
    Limpar-Conteudo "$Local\Spotify\Data"            'Spotify (cache de músicas)'
    Limpar-Conteudo "$Local\Spotify\Storage"         'Spotify (storage)'
    Limpar-Conteudo "$Local\Stremio\stremio-cache"   'Stremio (cache de streaming)'
    # Celestial (skins do LoL): é cache, mas ele baixa tudo de novo depois. Comente se incomodar.
    Remover-Pasta   "$Roaming\com.divineskins.celestial\storage"     'Celestial (storage)'
    Remover-Pasta   "$Roaming\com.divineskins.celestial\lmdb-hashes" 'Celestial (hashes)'

    # ── 2. Temporários e dumps ──────────────────────────────────────────────
    "`n== Temporários =="
    Limpar-Conteudo "$Local\Temp"        'Temp do usuário'
    Limpar-Conteudo "$Local\CrashDumps"  'Crash dumps'
    Limpar-Conteudo 'C:\Windows\Temp'    'Temp do Windows'

    # ── 3. Instaladores acumulados ──────────────────────────────────────────
    "`n== Instaladores de driver =="
    # O NVIDIA App guarda uma cópia de cada driver baixado (~0,8 GB cada, chegou a 25 GB).
    Limpar-Conteudo 'C:\ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts' 'NVIDIA App (drivers antigos)'
    # Dell SupportAssist / Alienware Update: pacotes de driver já aplicados.
    Limpar-Conteudo 'C:\ProgramData\Dell\drivers' 'Dell (drivers baixados)'
    # Instaladores de driver NVIDIA baixados manualmente.
    Get-ChildItem "$Perfil\Downloads" -File -Filter '*-win10-win11-64bit-international-*.exe' -ErrorAction SilentlyContinue | ForEach-Object {
        Registrar $_.Length "Downloads\$($_.Name)"
        if (-not $script:Seco) { Remove-Item -LiteralPath $_.FullName -Force }
    }

    # ── 4. Cache do Windows Update ──────────────────────────────────────────
    "`n== Windows Update =="
    if (-not $script:Seco) { Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue }
    Limpar-Conteudo 'C:\Windows\SoftwareDistribution\Download' 'Windows Update (downloads)'
    if (-not $script:Seco) { Start-Service wuauserv, bits -ErrorAction SilentlyContinue }

    # ── 5. Sobras de apps já desinstalados ──────────────────────────────────
    # Só apaga se o app NÃO estiver instalado. Se você reinstalar um deles, os dados ficam.
    "`n== Sobras de apps desinstalados =="
    if (-not (Test-Path "$Local\Google\Chrome SxS\Application\chrome.exe")) {
        Remover-Pasta "$Local\Google\Chrome SxS" 'Chrome Canary (sobras)'
    }
    if (-not (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')) {
        # Só os dados do navegador. O WebView2 (EdgeWebView) fica: vários apps dependem dele.
        Remover-Pasta "$Local\Microsoft\Edge" 'Edge (sobras de dados)'
    }
    if (-not (Test-Path "$Local\BraveSoftware\Brave-Browser\Application\brave.exe") -and
        -not (Test-Path 'C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe')) {
        Remover-Pasta "$Local\BraveSoftware" 'Brave (sobras)'
        if (-not $script:Seco) {
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'BraveSoftware Update' -ErrorAction SilentlyContinue
            Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object TaskName -match 'BraveSoftwareUpdate' |
                Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    # ── 6. Lixeira ──────────────────────────────────────────────────────────
    "`n== Lixeira =="
    Registrar (Get-Tamanho 'C:\$Recycle.Bin') 'Lixeira'
    if (-not $script:Seco) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }

    # ── 7. Inicialização automática ─────────────────────────────────────────
    # Desativa pelo mesmo mecanismo do Gerenciador de Tarefas (reversível por lá).
    # Vários desses apps se reativam sozinhos em atualizações, por isso fica aqui.
    "`n== Inicialização automática =="
    $desativar = 'EpicGamesLauncher', 'Steam', 'Hydra', 'Free Download Manager', 'NVIDIA Broadcast', 'Discord'
    $approved  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    $run       = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    $estado    = Get-ItemProperty $approved -ErrorAction SilentlyContinue
    foreach ($nome in $desativar) {
        if (-not $run.PSObject.Properties[$nome]) { continue }
        # Primeiro byte 3 = já desativado.
        if ($estado.PSObject.Properties[$nome] -and $estado.$nome[0] -eq 3) { continue }
        "            desativar: $nome"
        if (-not $script:Seco) {
            if (-not (Test-Path $approved)) { New-Item $approved -Force | Out-Null }
            Set-ItemProperty $approved -Name $nome -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) -Type Binary
        }
    }

    # ── 8. Componentes do Windows (WinSxS) ──────────────────────────────────
    "`n== DISM =="
    if ($SemDism) {
        '            pulado (-SemDism)'
    } elseif (Test-ReinicioPendente) {
        '            pulado: há uma reinicialização pendente (o DISM falha com 0x800f0806). Reinicie e rode de novo.'
    } elseif ($script:Seco) {
        '            será executado (ganho não estimável, costuma ser 1–5 GB)'
    } else {
        dism.exe /Online /Cleanup-Image /StartComponentCleanup
    }
}

# ── Execução real (admin) ───────────────────────────────────────────────────
function Invoke-Execucao {
    $logDir = Join-Path $Local 'limpeza-sistema\logs'
    New-Item -ItemType Directory -Force $logDir | Out-Null
    Start-Transcript -Path (Join-Path $logDir ("limpeza-{0:yyyyMMdd-HHmm}.log" -f (Get-Date))) | Out-Null
    $livreAntes        = (Get-PSDrive C).Free
    $script:Seco       = $false
    $script:totalBytes = 0
    Invoke-Limpeza
    "`n== Resultado =="
    "Livre no C:  {0:N1} GB  (+{1:N1} GB)" -f ((Get-PSDrive C).Free / 1GB), (((Get-PSDrive C).Free - $livreAntes) / 1GB)
    Stop-Transcript | Out-Null
}

if ($Confirmado) {
    if (-not $isAdmin) { Write-Error '-Confirmado precisa ser rodado como administrador.'; return }
    Invoke-Execucao
    Read-Host "`nEnter para fechar" | Out-Null
    return
}

# ── Estimativa (sem admin) ──────────────────────────────────────────────────
"Calculando o que pode ser apagado...`n"
Invoke-Limpeza
"`n== Total =="
"Estimativa: ~{0:N1} GB (sem contar o DISM)" -f ($script:totalBytes / 1GB)
if (-not $isAdmin) { '(algumas pastas de sistema só são medidas por completo como admin)' }

if ($Simular) { return }

$resposta = Read-Host "`nApagar tudo isso? [s/N]"
if ($resposta -notmatch '^(s|sim|y|yes)$') { 'Cancelado. Nada foi apagado.'; return }

if ($isAdmin) {
    Invoke-Execucao
} else {
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Confirmado', '-Perfil', "`"$Perfil`"")
    if ($SemDism) { $argv += '-SemDism' }
    'Abrindo janela de administrador (aceite o UAC)...'
    try {
        Start-Process pwsh -Verb RunAs -ArgumentList $argv -ErrorAction Stop
    } catch {
        'UAC recusado. Nada foi apagado.'
    }
}


<# ════════════════════════════════════════════════════════════════════════════
   HISTÓRICO — ações feitas UMA VEZ em 14/11/2026 (não replicáveis)
   C: passou de 99,5 GB para ~194 GB livres.
   ════════════════════════════════════════════════════════════════════════════

   WSL removido por completo (não era usado)
     - wsl --unregister FedoraLinux-42   (distro de 12/12/2025, disco ext4.vhdx de 7 GB)
     - Remove-Item "$env:LOCALAPPDATA\wsl" -Recurse
     - Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForLinux | Remove-AppxPackage
     - Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
     - "Plataforma de Máquina Virtual" (VirtualMachinePlatform) foi MANTIDA.

   Desinstalados
     - Podman 5.8.9 (dependia do WSL) + ~\.local\share\containers e ~\.config\containers
     - Equibop 3.3.2 (bugado; ficou o Discord oficial) + atalho em shell:startup
     - Plexamp 4.12.3 (duplicado; ficou o 4.50.19 em %LOCALAPPDATA%\Plexamp)
     - GnuWin32 Make 3.81 e ezwinports make (winget uninstall --id ezwinports.make)
     - AOMEI Partition Assistant + C:\Aomei
     - Mozilla Firefox + perfil (%APPDATA%\Mozilla\Firefox, %LOCALAPPDATA%\Mozilla\Firefox)
     - TikTok LIVE Studio
     - Ubisoft Connect + C:\ProgramData\Ubisoft
     - Brave (já estava desinstalado; removidas pastas, chave HKCU\Software\BraveSoftware,
       2 tarefas agendadas e a entrada de inicialização)
     - Edge (já estava desinstalado; removidos só os dados)

   Arquivos pessoais apagados
     - C:\PS3\Diablo III - Reaper of Souls (ISO de PS3, 11,7 GB)
     - %LOCALAPPDATA%\koharu (3,5 GB)
     - Downloads\StremioSetup-v5.0.27_x64.exe

   MANTIDOS de propósito — não apagar
     - %LOCALAPPDATA%\Microsoft\WinGet\Packages: NÃO é cache, são programas instalados
       (Claude Code, bat, eza, fzf, zoxide, Syncthing, WinLibs, Bun, Rufus...).
     - Microsoft Edge WebView2 Runtime: usado por vários apps.
     - Mozilla Maintenance Service: atualiza o Thunderbird, que continua instalado.
     - WinLibs (GCC): traz um mingw32-make, mas é a toolchain inteira.
     - C:\ProgramData\NVIDIA\NGX (4,4 GB): modelos de DLSS usados pelos jogos.
     - C:\Windows\Installer e WinSxS manual: só via DISM, nunca apagar à mão.

   Pendente (decisão do usuário)
     - OneDrive (~9,5 GB) vs Nextcloud: OneDrive não é usado, ainda a analisar.
#>
