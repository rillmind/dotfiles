# O '-Verb RunAs' é o equivalente a "Executar como administrador"

# Em uso:

Start-Process syncthing -ArgumentList "--no-browser" -WindowStyle Hidden
Start-Process -FilePath "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
# Tema salvo (barra + papel de parede); hoje o Catppuccin, com o YASB.
& "$PSScriptRoot\tema.ps1" iniciar | Out-Null
Start-Process -FilePath "C:\Program Files (x86)\Thermal Control Center\tcc-g15.exe" -Verb RunAs

# Preferências (NumLock etc.): silencioso, só pede UAC se algo de admin tiver sido revertido.
& "$PSScriptRoot\preferencias.ps1" | Out-Null

# Ajustes de jogos: só abre a janela se uma atualização do Windows reverteu algum.
# "[?]" não conta: são itens que só dá para checar como admin.
if ((& "$PSScriptRoot\otimizacao-jogos.ps1" -Simular) -match '^\[mudar\]') {
    Start-Process pwsh -ArgumentList '-NoExit', '-NoProfile', '-File', "`"$PSScriptRoot\otimizacao-jogos.ps1`""
}

# Limpeza de cache do sistema e dos apps: em segundo plano, como admin (um UAC), sem
# fechar app aberto nem esvaziar a Lixeira. O resultado fica em
# %LOCALAPPDATA%\limpeza-sistema\logs.
Start-Process pwsh -Verb RunAs -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$PSScriptRoot\limpeza-sistema.ps1`"", '-Confirmado', '-Silencioso', '-Perfil', "`"$env:USERPROFILE`"" `
    -ErrorAction SilentlyContinue  # UAC recusado: fica para a próxima

# Em desuso:

#Start-Process -FilePath "C:\Users\raios\AppData\Local\FlowLauncher\Flow.Launcher.exe"
#komorebic start --whkd
