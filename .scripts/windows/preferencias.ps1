#Requires -Version 7
<#
.SYNOPSIS
    Preferências pessoais do Windows que não são de limpeza nem de jogos.

.DESCRIPTION
    Cada ajuste checa o estado atual e só é aplicado se estiver diferente.
    Abre o UAC só se houver ajuste de admin pendente.
#>
param([switch]$Confirmado)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# NumLock ligado no boot. "2" é ignorado com a Inicialização rápida ativa;
# 2147483650 (0x80000002) funciona com ela. .DEFAULT vale para a tela de login.
$NumLock = '2147483650'
$Ajustes = @(
    @{ Nome = 'NumLock ligado (usuário)';     Admin = $false; Chave = 'HKCU:\Control Panel\Keyboard' }
    @{ Nome = 'NumLock ligado (tela de login)'; Admin = $true;  Chave = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' }
)

function Test-Ok($a) { (Get-ItemProperty $a.Chave).InitialKeyboardIndicators -eq $NumLock }
function Invoke-Ajustes([bool]$Admin) {
    foreach ($a in $Ajustes | Where-Object { $_.Admin -eq $Admin -and -not (Test-Ok $_) }) {
        "aplicando: $($a.Nome)"
        Set-ItemProperty $a.Chave InitialKeyboardIndicators $NumLock -Type String
    }
}

if ($Confirmado) { Invoke-Ajustes $true; return }

foreach ($a in $Ajustes) { "{0} {1}" -f $(if (Test-Ok $a) { '[ok]   ' } else { '[mudar]' }), $a.Nome }
Invoke-Ajustes $false

if ($Ajustes | Where-Object { $_.Admin -and -not (Test-Ok $_) }) {
    if ($isAdmin) { Invoke-Ajustes $true }
    else {
        try { Start-Process pwsh -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile', '-File', "`"$PSCommandPath`"", '-Confirmado' -ErrorAction Stop }
        catch { 'UAC recusado. A tela de login não foi alterada.' }
    }
}
