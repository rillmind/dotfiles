# O '-Verb RunAs' é o equivalente a "Executar como administrador"

# Em uso:

Start-Process syncthing -ArgumentList "--no-browser" -WindowStyle Hidden
Start-Process -FilePath "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
yasb
Start-Process -FilePath "C:\Program Files (x86)\Thermal Control Center\tcc-g15.exe" -Verb RunAs

# Preferências (NumLock etc.): silencioso, só pede UAC se algo de admin tiver sido revertido.
& "$PSScriptRoot\preferencias.ps1" | Out-Null

# Ajustes de jogos: só abre a janela se uma atualização do Windows reverteu algum.
# "[?]" não conta: são itens que só dá para checar como admin.
if ((& "$PSScriptRoot\otimizacao-jogos.ps1" -Simular) -match '^\[mudar\]') {
    Start-Process pwsh -ArgumentList '-NoExit', '-NoProfile', '-File', "`"$PSScriptRoot\otimizacao-jogos.ps1`""
}

# Em desuso:

#Start-Process -FilePath "C:\Users\raios\AppData\Local\FlowLauncher\Flow.Launcher.exe"
#komorebic start --whkd
