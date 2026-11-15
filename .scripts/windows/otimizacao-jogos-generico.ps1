<#
.SYNOPSIS
    Ajustes de desempenho para jogos em qualquer PC com Windows 10/11.

.DESCRIPTION
    Versão genérica de otimizacao-jogos.ps1: não tem caminhos fixos nem hardware
    específico. Detecta notebook/desktop, as bibliotecas de jogos dos launchers e se
    o PC usa WSL/Docker antes de mexer em virtualização.

    Cada ajuste checa o estado atual e só é aplicado se estiver diferente do desejado,
    então dá para rodar sempre (atualizações do Windows às vezes revertem alguns).

    Fluxo: mostra o estado, pede confirmação [S/n], pergunta à parte sobre os ajustes
    que reduzem a segurança [s/N], aplica os de usuário e abre o UAC para os de sistema.

    Funciona no Windows PowerShell 5.1 e no PowerShell 7. Em PC que bloqueia scripts:
        powershell -ExecutionPolicy Bypass -File .\otimizacao-jogos-generico.ps1

.PARAMETER Simular
    Só mostra o estado atual, sem perguntar nem aplicar nada.

.PARAMETER IncluirSeguranca
    Aplica também os ajustes que reduzem a segurança (VBS, HVCI, Credential Guard,
    Hyper-V...) sem perguntar.

.PARAMETER Confirmado
    Aplica direto os ajustes de admin, sem perguntar (usado internamente após o UAC).
#>
param(
    [switch]$Simular,
    [switch]$IncluirSeguranca,
    [switch]$Confirmado
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ── Helpers ─────────────────────────────────────────────────────────────────
function Get-Reg([string]$Path, [string]$Name) {
    (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue).$Name
}

function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type
}

function Get-RecursoOpcional([string]$Nome) {
    # 1 = habilitado, 2 = desabilitado. Win32_OptionalFeature não exige admin.
    (Get-CimInstance Win32_OptionalFeature -Filter "Name='$Nome'" -ErrorAction SilentlyContinue).InstallState
}

# Overlay do modo de energia (o slider "Modo de energia" das Configurações).
Add-Type -Namespace Win32 -Name Power -MemberDefinition @'
[DllImport("powrprof.dll")] public static extern uint PowerSetActiveOverlayScheme(Guid scheme);
'@
$OverlayDesempenho = 'ded574b5-45a0-4f42-8737-46345c09c238'   # Melhor desempenho
$OverlayNomes = @{
    '961cc777-2547-4f9d-8174-7d86181b8a7a' = 'Melhor eficiência energética'
    '00000000-0000-0000-0000-000000000000' = 'Equilibrado'
    $OverlayDesempenho                     = 'Melhor desempenho'
}
# Planos clássicos que já são de desempenho máximo (o overlay não se aplica a eles).
$PlanosDesempenho = @(
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # Alto desempenho
    'e9a42b02-d5df-448d-aa00-03f14749eb61'   # Desempenho Máximo
)

$Notebook = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)

function Get-NaTomada {
    if (-not $Notebook) { return $true }
    [bool](Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Where-Object PowerOnline)
}

function Get-PlanoAtivo {
    if ((powercfg /getactivescheme) -match '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}') { $Matches[0] }
}

# Motivos para NÃO desligar Hyper-V/Plataforma de VM: quebraria algo que o PC usa.
function Get-UsoVirtualizacao {
    $usos = @()
    $wsl = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue |
        ForEach-Object { (Get-ItemProperty $_.PSPath).DistributionName } | Where-Object { $_ }
    if ($wsl) { $usos += "WSL ($($wsl -join ', '))" }
    if (Test-Path "$env:ProgramFiles\Docker\Docker") { $usos += 'Docker Desktop' }
    if ((Get-RecursoOpcional 'Containers-DisposableClientVM') -eq 1) { $usos += 'Windows Sandbox' }
    $usos
}
$UsoVirtualizacao = @(Get-UsoVirtualizacao)
$PularVirtualizacao = { if ($UsoVirtualizacao) { "em uso por: $($UsoVirtualizacao -join ', ')" } }

function Get-DefenderAtivo {
    $s = Get-MpComputerStatus -ErrorAction SilentlyContinue
    [bool]($s -and $s.AMRunningMode -eq 'Normal' -and $s.RealTimeProtectionEnabled)
}

# Pastas de jogos dos launchers instalados (só as que existem).
function Get-PastasJogos {
    $pastas = @()

    # Steam: todas as bibliotecas listadas em libraryfolders.vdf.
    $steam = Get-Reg 'HKCU:\Software\Valve\Steam' 'SteamPath'
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        $libs = @($steam)
        if (Test-Path $vdf) {
            $libs += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
        }
        # Concatenação em vez de Join-Path: biblioteca em drive desconectado faria Join-Path falhar.
        $pastas += $libs | ForEach-Object { "$($_.TrimEnd('\'))\steamapps" }
    }

    # Epic: um manifesto por jogo instalado.
    Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue | ForEach-Object {
        $pastas += (Get-Content $_.FullName -Raw | ConvertFrom-Json).InstallLocation
    }

    # GOG e Ubisoft guardam a pasta de cada jogo no registro.
    $pastas += Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games' -ErrorAction SilentlyContinue | ForEach-Object { (Get-ItemProperty $_.PSPath).path }
    $pastas += Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs' -ErrorAction SilentlyContinue | ForEach-Object { (Get-ItemProperty $_.PSPath).InstallDir }

    # Riot, Blizzard e EA: pelos registros de desinstalação dos jogos. Ficam de fora os
    # launchers e o anti-cheat (Vanguard), que não são jogos.
    $pastas += Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Publisher -match 'Riot Games|Blizzard|Electronic Arts' -and $_.InstallLocation -and
                       $_.DisplayName -notmatch 'Vanguard|Riot Client|^Battle\.net$|^EA app$|^Origin$' } |
        ForEach-Object { $_.InstallLocation }

    # Normaliza, mantém só as que existem e tira as que estão dentro de outra da lista.
    $pastas = $pastas | Where-Object { $_ } | ForEach-Object { ($_.Trim('"') -replace '/', '\').TrimEnd('\') } |
        Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique
    $pastas | Where-Object { $p = $_; -not ($pastas | Where-Object { $_ -ne $p -and $p.StartsWith("$_\", 'OrdinalIgnoreCase') }) }
}
$PastasJogos = @(Get-PastasJogos)

$dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'

# ── Ajustes ─────────────────────────────────────────────────────────────────
# Ok: $true = já está certo, $false = precisa aplicar, $null = não dá para checar sem admin.
# Pular (opcional): devolve o motivo para não aplicar neste PC.
# Seguranca: só é aplicado se o usuário aceitar a pergunta à parte (ou -IncluirSeguranca).
# Ordem dos de admin: o mais demorado primeiro.
$Ajustes = @(
    # ---------- usuário ----------
    @{
        Nome = 'Modo de energia: Melhor desempenho'
        Admin = $false; Reinicio = $false
        Ok = {
            if ((Get-PlanoAtivo) -in $PlanosDesempenho) { return $true }
            (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme') -eq $OverlayDesempenho
        }
        Atual = { $g = Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme'; if ($g -and $OverlayNomes[$g]) { $OverlayNomes[$g] } elseif ($g) { $g } else { 'Equilibrado' } }
        Aplicar = {
            # O overlay vale para a fonte de energia atual; no notebook só aplica na tomada.
            if (-not (Get-NaTomada)) { 'pulado: ligue o notebook na tomada e rode de novo'; return }
            [void][Win32.Power]::PowerSetActiveOverlayScheme([Guid]$OverlayDesempenho)
        }
    }
    @{
        Nome = 'Otimizações para jogos em janela'
        Admin = $false; Reinicio = $false
        Ok = { (Get-Reg $dxKey 'DirectXUserGlobalSettings') -match 'SwapEffectUpgradeEnable=1;' }
        Aplicar = {
            $atual = [string](Get-Reg $dxKey 'DirectXUserGlobalSettings')
            $novo  = if ($atual -match 'SwapEffectUpgradeEnable=\d;') { $atual -replace 'SwapEffectUpgradeEnable=\d;', 'SwapEffectUpgradeEnable=1;' } else { "${atual}SwapEffectUpgradeEnable=1;" }
            Set-Reg $dxKey 'DirectXUserGlobalSettings' $novo 'String'
        }
    }
    @{
        Nome = 'Modo de Jogo ligado'
        Admin = $false; Reinicio = $false
        Ok = { (Get-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
        Aplicar = { Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 }
    }
    @{
        Nome = 'Gravação em segundo plano (Game DVR) desligada'
        Admin = $false; Reinicio = $false
        Ok = { (Get-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') -eq 0 -and
               (Get-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled') -eq 0 }
        Aplicar = {
            Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
        }
    }
    # ---------- admin ----------
    @{
        # Com o Hyper-V ligado o Windows inteiro roda sobre o hypervisor e a VBS
        # continua ativa mesmo com as chaves de registro zeradas.
        Nome = 'Hyper-V desligado'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Pular = $PularVirtualizacao
        Ok = { (Get-RecursoOpcional 'Microsoft-Hyper-V-All') -ne 1 }
        Aplicar = { Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -WarningAction SilentlyContinue | Out-Null }
    }
    @{
        Nome = 'Plataforma de Máquina Virtual desligada'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Pular = $PularVirtualizacao
        Ok = { (Get-RecursoOpcional 'VirtualMachinePlatform') -ne 1 }
        Aplicar = { Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue | Out-Null }
    }
    @{
        # Sem isso o Windows ainda sobe o hypervisor quando algum recurso pede VBS.
        Nome = 'Hypervisor não inicia no boot'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Pular = $PularVirtualizacao
        Ok = {
            if (-not $isAdmin) { return $null }
            [bool]((bcdedit /enum '{current}') -match '^hypervisorlaunchtype\s+Off')
        }
        Aplicar = { bcdedit /set '{current}' hypervisorlaunchtype off | Out-Null }
    }
    @{
        # A Entrada Avançada do Windows Hello exige VBS. Só faz sentido com leitor
        # biométrico; sem ele, só mantém a VBS ligada à toa.
        Nome = 'Entrada Avançada do Windows Hello (ESS) desligada'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Pular = { if (Get-PnpDevice -Class Biometric -PresentOnly -ErrorAction SilentlyContinue) { 'o PC tem leitor biométrico: a ESS protege o Windows Hello' } }
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' 'Enabled') -ne 1 }
        Aplicar = {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' 'Enabled' 0
            'o PIN atual deixa de funcionar após reiniciar: entre com a senha, rode'
            '`certutil -DeleteHelloContainer`, saia da conta e crie um PIN novo.'
        }
    }
    @{
        Nome = 'Integridade de Memória (HVCI) desligada'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled') -ne 1 }
        Aplicar = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 }
    }
    @{
        Nome = 'Credential Guard desligado'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags') -eq 0 }
        Aplicar = {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags' 0
            if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard') { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard' 'LsaCfgFlags' 0 }
        }
    }
    @{
        Nome = 'Segurança baseada em virtualização (VBS) desligada'
        Admin = $true; Reinicio = $true; Seguranca = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity') -eq 0 }
        Aplicar = {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0
            # Uma política, se existir, tem prioridade sobre a chave acima.
            if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard') { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0 }
        }
    }
    @{
        # Em GPU sem suporte (antes de GTX 10xx / RX 5000) o Windows simplesmente ignora.
        Nome = 'Agendamento de GPU acelerado por hardware (HAGS)'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2 }
        Aplicar = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 }
    }
    @{
        Nome = "Exclusões do Defender nas bibliotecas de jogos ($($PastasJogos.Count) pastas)"
        Admin = $true; Reinicio = $false
        Pular = {
            if (-not (Get-DefenderAtivo)) { 'o Defender não é o antivírus ativo' }
            elseif (-not $PastasJogos) { 'nenhuma biblioteca de jogos encontrada' }
        }
        Ok = {
            if (-not $isAdmin) { return $null }
            $atuais = @((Get-MpPreference).ExclusionPath)
            -not ($PastasJogos | Where-Object { $_ -notin $atuais })
        }
        Aplicar = { Add-MpPreference -ExclusionPath $PastasJogos }
    }
)

function Get-Motivo($a) { if ($a.Pular) { & $a.Pular } }

function Show-Estado {
    foreach ($a in $Ajustes) {
        $motivo = Get-Motivo $a
        $ok = if ($motivo) { $null } else { & $a.Ok }
        $marca = if ($motivo) { '[pular]' } elseif ($ok -eq $true) { '[ok]   ' } elseif ($ok -eq $false) { '[mudar]' } else { '[?]    ' }
        $extra = if ($motivo) { "  ($motivo)" } elseif ($a.Atual -and $ok -ne $true) { "  (atual: $(& $a.Atual))" } else { '' }
        $tags  = @(); if ($a.Admin) { $tags += 'admin' }; if ($a.Reinicio) { $tags += 'reiniciar' }; if ($a.Seguranca) { $tags += 'segurança' }
        "{0} {1}{2}{3}" -f $marca, $a.Nome, $(if ($tags) { "  [$($tags -join ', ')]" } else { '' }), $extra
    }
}

function Test-Pendente($a) { -not (Get-Motivo $a) -and (& $a.Ok) -ne $true }

# Imprime o progresso e marca $script:Reiniciar se algum ajuste aplicado exigir reinício.
$script:Reiniciar = $false
function Invoke-Ajustes([bool]$Admin) {
    foreach ($a in $Ajustes | Where-Object { [bool]$_.Admin -eq $Admin }) {
        if ($a.Seguranca -and -not $IncluirSeguranca) { continue }
        if (-not (Test-Pendente $a)) { continue }
        "aplicando: $($a.Nome)"
        & $a.Aplicar | ForEach-Object { "           $_" }
        if ($a.Reinicio) { $script:Reiniciar = $true }
    }
}

# ── Fase admin (após o UAC) ─────────────────────────────────────────────────
if ($Confirmado) {
    if (-not $isAdmin) { Write-Error '-Confirmado precisa ser rodado como administrador.'; return }
    Invoke-Ajustes $true
    "`n== Estado final =="
    Show-Estado
    if ($script:Reiniciar) { "`n>>> Reinicie o PC para os ajustes de sistema valerem. <<<" }
    Read-Host "`nEnter para fechar" | Out-Null
    return
}

# ── Estado atual ────────────────────────────────────────────────────────────
"== Estado atual ($(if ($Notebook) { 'notebook' } else { 'desktop' })) ==`n"
Show-Estado
if ($PastasJogos) { "`nBibliotecas de jogos encontradas:"; $PastasJogos | ForEach-Object { "  $_" } }
if ($Simular) { return }

$pendentes = @($Ajustes | Where-Object { Test-Pendente $_ })
if (-not $pendentes) { "`nTudo já está aplicado."; return }

$resposta = Read-Host "`nAplicar os ajustes marcados? [S/n]"
if ($resposta -match '^(n|nao|não|no)$') { 'Cancelado. Nada foi alterado.'; return }

if (-not $IncluirSeguranca -and ($pendentes | Where-Object Seguranca)) {
    ''
    'Os ajustes marcados [segurança] dão ~5-10% a mais em jogos limitados pela CPU,'
    'mas reduzem a proteção contra malware de kernel. Não aplique em PC de trabalho'
    'ou gerenciado pela empresa. Desligar Hyper-V/Plataforma de VM quebra WSL2, Docker'
    'e emuladores Android baseados em Hyper-V.'
    $IncluirSeguranca = (Read-Host 'Aplicar também os de segurança? [s/N]') -match '^(s|sim|y|yes)$'
}

"`n== Ajustes de usuário =="
Invoke-Ajustes $false

$adminPendentes = $pendentes | Where-Object { $_.Admin -and ($IncluirSeguranca -or -not $_.Seguranca) }
if ($adminPendentes) {
    if ($isAdmin) {
        Invoke-Ajustes $true
        if ($script:Reiniciar) { "`n>>> Reinicie o PC para os ajustes de sistema valerem. <<<" }
    } else {
        "`nAbrindo janela de administrador para os ajustes de sistema (aceite o UAC)..."
        $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Confirmado')
        if ($IncluirSeguranca) { $argumentos += '-IncluirSeguranca' }
        try {
            # Reabre no mesmo PowerShell em uso (5.1 ou 7).
            Start-Process (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argumentos -ErrorAction Stop
        } catch {
            'UAC recusado. Os ajustes de sistema não foram aplicados.'
        }
    }
}


<# ════════════════════════════════════════════════════════════════════════════
   NOTAS — o que não dá para automatizar
   ════════════════════════════════════════════════════════════════════════════

   Manuais (fazer na mão)
     - Driver de vídeo atualizado direto do fabricante (NVIDIA App, AMD Adrenalin,
       Intel Arc Control), não o do Windows Update.
     - Configurações > Tela > Tela avançada: conferir se a taxa de atualização está no
       máximo do monitor (vem em 60 Hz em muitos monitores de 144 Hz+).
     - Desktop: cabo do monitor ligado na placa de vídeo, não na placa-mãe.
     - Desktop: ativar XMP/EXPO na BIOS (sem isso a RAM roda bem abaixo da velocidade
       anunciada) e Resizable BAR / Smart Access Memory.
     - RAM: dois pentes iguais (dual channel) rendem bem mais que um pente só.
     - Notebook: jogar na tomada, com o perfil de desempenho do software do fabricante
       (Armoury Crate, Legion Vantage, Alienware/Dell, Omen...) e em local ventilado.
     - Nos jogos: ligar NVIDIA Reflex / AMD Anti-Lag quando houver, e usar DLSS/FSR/XeSS
       em vez de baixar a resolução.
     - Jogos em SSD (de preferência NVMe), nunca em HD mecânico.

   Trade-offs dos ajustes de segurança
     - Secure Boot e TPM continuam ligados (exigidos por anti-cheats como Riot Vanguard
       e FACEIT). Se algum anti-cheat reclamar da VBS/HVCI, religue em
       Segurança do Windows > Segurança do dispositivo > Isolamento de núcleo.
     - Para desfazer Hyper-V/Plataforma de VM: "Ativar ou desativar recursos do Windows"
       e `bcdedit /set hypervisorlaunchtype auto` num terminal de admin.

   Não fazer
     - "Debloaters", desligar serviços em massa, tweaks de registro milagrosos,
       timer resolution, otimizadores e "limpadores" de RAM: ganho ~zero, risco alto.
#>
