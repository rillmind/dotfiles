#!/usr/bin/env pwsh

Write-Host "Instalando configuração do GlazeWM..." -ForegroundColor Cyan

# Caminhos
$repoConfig = "$HOME\dotfiles\.config\glazeWM\config.yaml"
$localDir = "$HOME\.glzr\glazewm"

if (Test-Path $repoConfig) {
  # Cria a pasta do sistema se não existir
  if (!(Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
  
  # Copia o arquivo
  Copy-Item -Path $repoConfig -Destination $localDir -Force
  
  Write-Host "Configuração instalada em: $localDir" -ForegroundColor Green
} else {
  Write-Host "Erro: Configuração não encontrada nos dotfiles ($repoConfig)." -ForegroundColor Red
}