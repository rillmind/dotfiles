#!/usr/bin/env pwsh

Write-Host "Fazendo backup do GlazeWM..." -ForegroundColor Cyan

# Caminhos
$localConfig = "$HOME\.glzr\glazewm\config.yaml"
$repoDir = "$HOME\dotfiles\.config\glazeWM"

if (Test-Path $localConfig) {
	# Cria pasta no dotfiles se não existir
	if (!(Test-Path $repoDir)) { New-Item -ItemType Directory -Path $repoDir | Out-Null }
	
	# Copia o arquivo
	Copy-Item -Path $localConfig -Destination $repoDir -Force
	
	Write-Host "Backup salvo em: $repoDir" -ForegroundColor Green
} else {
	Write-Host "Erro: Arquivo local ($localConfig) não encontrado." -ForegroundColor Red
}