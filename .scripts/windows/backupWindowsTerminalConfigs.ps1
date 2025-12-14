#!/usr/bin/env pwsh

# Script que eu fiz:
# echo "Fazendo backup das configurações do Windows Terminal..."

# cat "C:\Users\raios\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" > ~/dotfiles/.config/windowsTerminal/settings.json

# sleep 0.5

# echo "Backup concluído!"

# Gemini:
# Definição de caminhos dinâmicos
$Source = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$Dest = "$HOME\dotfiles\.config\windowsTerminal\settings.json"

sleep 0.25

Write-Host "Fazendo backup das configurações..." -ForegroundColor Cyan

# Garante que a pasta de destino existe
$DestDir = Split-Path $Dest
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

# Copia o arquivo (Sobrescreve se existir)
Copy-Item -Path $Source -Destination $Dest -Force

sleep 0.75

Write-Host "Backup concluído em: $Dest" -ForegroundColor Green