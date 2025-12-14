#!/usr/bin/env pwsh

sleep 0.25

Write-Host "Fazendo instalação das configurações..." -ForegroundColor Cyan

$source = "$HOME\dotfiles\.config\alacrittyWindows\*"
$dest = "$env:APPDATA\alacritty"

if (!(Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
Copy-Item -Path $source -Destination $dest -Recurse -Force

sleep 0.75

Write-Host "Backup concluído em: $Dest" -ForegroundColor Green