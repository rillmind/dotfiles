#Requires -Version 7
<#
.SYNOPSIS
    Ajustes de desempenho para jogos no Dell G15 5530 (i5-13450HX, RTX 3050 6 GB, 16 GB DDR5).

.DESCRIPTION
    Cada ajuste checa o estado atual e só é aplicado se estiver diferente do desejado,
    então dá para rodar sempre (atualizações do Windows às vezes revertem alguns).

    Fluxo: mostra o estado de cada ajuste, pede confirmação, aplica os que não precisam
    de admin e depois abre o UAC para os de sistema. O que é manual ou foi decidido uma
    vez está no bloco "NOTAS" no fim do arquivo.

.PARAMETER Simular
    Só mostra o estado atual, sem perguntar nem aplicar nada.

.PARAMETER Confirmado
    Aplica direto os ajustes de admin, sem perguntar (usado internamente após o UAC).
#>
param(
    [switch]$Simular,
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

function Get-NaTomada { [bool](Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Where-Object PowerOnline) }

function Get-RecursoOpcional([string]$Nome) {
    # 1 = habilitado, 2 = desabilitado. Win32_OptionalFeature não exige admin.
    (Get-CimInstance Win32_OptionalFeature -Filter "Name='$Nome'" -ErrorAction SilentlyContinue).InstallState
}

# Pastas de jogos excluídas da verificação em tempo real do Defender.
# C:\Hydra (instaladores e jogos de repack) entrou por escolha: o Defender quarentena cracks e
# atrasa a extração. Contrapartida: nada ali é verificado, então só use repackers confiáveis.
$ExclusoesDefender = @(
    'C:\Hydra'
    'C:\Riot Games'
    'C:\Program Files (x86)\Steam\steamapps'
    'E:\SteamLibrary', 'F:\SteamLibrary', 'G:\SteamLibrary'
    'F:\Battle.net'
)

$dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'

# ── Ajustes ─────────────────────────────────────────────────────────────────
# Ok: $true = já está certo, $false = precisa aplicar, $null = não dá para checar sem admin.
# Ordem dos de admin: o mais demorado primeiro.
$Ajustes = @(
    # ---------- usuário ----------
    @{
        Nome = 'Modo de energia na tomada: Melhor desempenho'
        Admin = $false; Reinicio = $false
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme') -eq $OverlayDesempenho }
        Atual = { $g = Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme'; if ($OverlayNomes[$g]) { $OverlayNomes[$g] } else { $g } }
        Aplicar = {
            # O overlay vale para a fonte de energia atual; só aplica se estiver na tomada.
            if (-not (Get-NaTomada)) { 'pulado: ligue na tomada e rode de novo'; return }
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
        Ok = { (Get-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -eq 1 }
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
        # continua ativa mesmo com as chaves de registro abaixo zeradas.
        Nome = 'Hyper-V desligado (sobra do Podman/WSL)'
        Admin = $true; Reinicio = $true
        Ok = { (Get-RecursoOpcional 'Microsoft-Hyper-V-All') -ne 1 }
        Aplicar = { Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -WarningAction SilentlyContinue | Out-Null }
    }
    @{
        # Sem isso o Windows ainda sobe o hypervisor quando algum recurso pede VBS.
        Nome = 'Hypervisor não inicia no boot'
        Admin = $true; Reinicio = $true
        Ok = {
            if (-not $isAdmin) { return $null }
            [bool]((bcdedit /enum '{current}') -match '^hypervisorlaunchtype\s+Off')
        }
        Aplicar = { bcdedit /set '{current}' hypervisorlaunchtype off | Out-Null }
    }
    @{
        # Entrada Avançada do Windows Hello exige VBS; este PC não tem câmera IR nem leitor de digital.
        # Desligar invalida o PIN criado com ela: rodar `certutil -DeleteHelloContainer`, sair da
        # conta e criar um PIN novo em Configurações > Contas > Opções de entrada.
        Nome = 'Entrada Avançada do Windows Hello (ESS) desligada'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' 'Enabled') -ne 1 }
        Aplicar = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' 'Enabled' 0 }
    }
    @{
        Nome = 'Plataforma de Máquina Virtual desligada (sobra do WSL)'
        Admin = $true; Reinicio = $true
        Ok = { (Get-RecursoOpcional 'VirtualMachinePlatform') -ne 1 }
        Aplicar = { Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue | Out-Null }
    }
    @{
        Nome = 'Integridade de Memória (HVCI) desligada'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled') -eq 0 }
        Aplicar = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 }
    }
    @{
        Nome = 'Credential Guard desligado'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags') -eq 0 }
        Aplicar = {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags' 0
            if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard') { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard' 'LsaCfgFlags' 0 }
        }
    }
    @{
        Nome = 'Segurança baseada em virtualização (VBS) desligada'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity') -eq 0 }
        Aplicar = {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0
            # Uma política, se existir, tem prioridade sobre a chave acima.
            if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard') { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0 }
        }
    }
    @{
        Nome = 'Agendamento de GPU acelerado por hardware (HAGS)'
        Admin = $true; Reinicio = $true
        Ok = { (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2 }
        Aplicar = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 }
    }
    @{
        Nome = 'Exclusões do Defender nas pastas de jogos'
        Admin = $true; Reinicio = $false
        Ok = {
            if (-not $isAdmin) { return $null }
            $atuais = @((Get-MpPreference).ExclusionPath)
            -not ($ExclusoesDefender | Where-Object { $_ -notin $atuais })
        }
        Aplicar = { Add-MpPreference -ExclusionPath $ExclusoesDefender }
    }
)

function Show-Estado {
    foreach ($a in $Ajustes) {
        $ok = & $a.Ok
        $marca = switch ($ok) { $true { '[ok]   ' } $false { '[mudar]' } default { '[?]    ' } }
        $extra = if ($a.Atual -and $ok -ne $true) { "  (atual: $(& $a.Atual))" } else { '' }
        $tags  = @(); if ($a.Admin) { $tags += 'admin' }; if ($a.Reinicio) { $tags += 'reiniciar' }
        "{0} {1}{2}{3}" -f $marca, $a.Nome, $(if ($tags) { "  [$($tags -join ', ')]" } else { '' }), $extra
    }
}

# Imprime o progresso e marca $script:Reiniciar se algum ajuste aplicado exigir reinício.
$script:Reiniciar = $false
function Invoke-Ajustes([bool]$Admin) {
    foreach ($a in $Ajustes | Where-Object { $_.Admin -eq $Admin }) {
        if ((& $a.Ok) -eq $true) { continue }
        "aplicando: $($a.Nome)"
        $msg = & $a.Aplicar
        if ($msg) { "           $msg" }
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
"== Estado atual ==`n"
Show-Estado
if ($Simular) { return }

$pendentes = @($Ajustes | Where-Object { (& $_.Ok) -ne $true })
if (-not $pendentes) { "`nTudo já está aplicado."; return }

$resposta = Read-Host "`nAplicar os ajustes marcados? [S/n]"
if ($resposta -match '^(n|nao|não|no)$') { 'Cancelado. Nada foi alterado.'; return }

"`n== Ajustes de usuário =="
Invoke-Ajustes $false

if ($pendentes | Where-Object Admin) {
    if ($isAdmin) {
        Invoke-Ajustes $true
        if ($script:Reiniciar) { "`n>>> Reinicie o PC para os ajustes de sistema valerem. <<<" }
    } else {
        "`nAbrindo janela de administrador para os ajustes de sistema (aceite o UAC)..."
        try {
            Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Confirmado' -ErrorAction Stop
        } catch {
            'UAC recusado. Os ajustes de sistema não foram aplicados.'
        }
    }
}


<# ════════════════════════════════════════════════════════════════════════════
   NOTAS — análise de 14/11/2026 (o que não dá para automatizar)
   ════════════════════════════════════════════════════════════════════════════

   Hardware: Dell G15 5530 | i5-13450HX 10c/16t | RTX 3050 6 GB Laptop | 2×8 GB DDR5
   | tela 1080p 120 Hz.

   Já estava certo (não mexer)
     - RAM em dual channel. Os pentes são 5600, mas rodam a 4800: é o máximo do
       i5-13450HX, não é defeito nem configuração.
     - A RTX liga direto no painel (Intel UHD sem saída ativa = modo dGPU/MUX).
     - SysMain parado: irrelevante em NVMe.
     - Uso de RAM em repouso ~6 GB. NÃO usar "limpadores de RAM": pioram o desempenho.

   Manuais (fazer na mão)
     - G-Mode / perfil de desempenho no Thermal Control Center (tcc-g15) ao jogar.
       Notebook perde clock por temperatura: ventoinha no máximo e base com cooler ajudam.
     - Limpeza interna + pasta térmica nova a cada 1–2 anos devolve bastante desempenho.
     - Fechar navegadores (Chrome/Zen) e Discord em jogos pesados: é o que mais libera RAM.
     - 32 GB só vale para jogos que passam de 12–14 GB (BG3 ato 3, RE com texturas máximas).
     - O F: é um SSD externo via USB: jogar dali tem impacto pequeno. Se algum jogo de
       mundo aberto engasgar ao carregar áreas, mover para o NVMe interno (C:).

   Trade-offs dos ajustes de segurança
     - HVCI + VBS + Credential Guard desligados: ganho de ~5–10% em jogos limitados pela
       CPU, em troca de menos proteção contra drivers/malware de kernel.
       Secure Boot e TPM continuam ligados (exigidos pelo Riot Vanguard).
       Se o Vanguard ou algum anti-cheat reclamar, religue em
       Segurança do Windows > Segurança do dispositivo > Isolamento de núcleo.
     - Desligar a Plataforma de Máquina Virtual quebra emuladores Android e Docker.

   Não fazer
     - "Debloaters", desligar serviços em massa, tweaks de registro milagrosos,
       timer resolution, otimizadores de RAM: ganho ~zero, risco alto.
       O Windows (LTSC IoT) já vem sem a maioria dos apps de fábrica.
#>
