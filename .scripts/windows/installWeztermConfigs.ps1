#!/usr/bin/env pwsh

Write-Host "Ligando a configuração do WezTerm ao dotfiles..." -ForegroundColor Cyan

# Link simbólico: editar o arquivo no dotfiles já recarrega o WezTerm
$source = "$HOME\dotfiles\.config\wezterm\wezterm.lua"
$dest = "$HOME\.config\wezterm\wezterm.lua"

$destDir = Split-Path $dest
if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

New-Item -ItemType SymbolicLink -Path $dest -Target $source -Force | Out-Null

Write-Host "Link criado: $dest -> $source" -ForegroundColor Green
