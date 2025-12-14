#!/usr/bin/env pwsh

sleep 0.25

Write-Host "Iniciando backup das configurações..." -ForegroundColor Cyan

$source = "$env:APPDATA\alacritty"
$dest = "$HOME\dotfiles\.config\alacrittyWindows"

# Verifica se a origem existe antes de copiar
if (Test-Path $source) {
  if (!(Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
  
  # Copia o conteúdo da pasta alacritty para dentro de alacrittyWindows
  Copy-Item -Path "$source\*" -Destination $dest -Recurse -Force

  sleep 0.75
  Write-Host "Backup salvo em: $dest" -ForegroundColor Green
} else {
  Write-Host "Erro: A pasta de origem ($source) não foi encontrada." -ForegroundColor Red
}