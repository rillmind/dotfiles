#!/usr/bin/env pwsh

Write-Host "Buscando instalação do Windows Terminal..." -ForegroundColor Cyan

# Detecta o pacote (Prioriza a versão Estável se ambas existirem)
$Pkg = Get-AppxPackage -Name "*WindowsTerminal*" | Sort-Object Name | Select-Object -First 1

if (-not $Pkg) {
    Write-Error "ERRO: Windows Terminal não encontrado no sistema."
    exit 1
}

Write-Host "Versão detectada: $($Pkg.Name)" -ForegroundColor Gray

# Define caminhos dinâmicos
$Source = "$env:LOCALAPPDATA\Packages\$($Pkg.PackageFamilyName)\LocalState\settings.json"
$Dest   = "$HOME\dotfiles\.config\windowsTerminal\settings.json"

# Verifica se o arquivo de configuração existe na origem
if (-not (Test-Path $Source)) {
    Write-Error "ERRO: settings.json não encontrado em: $Source"
    exit 1
}

# Cria pasta de destino se não existir
$DestDir = Split-Path $Dest
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

# Executa o backup
Copy-Item -Path $Source -Destination $Dest -Force

Write-Host "Backup concluído com sucesso!" -ForegroundColor Green
Write-Host "Destino: $Dest" -ForegroundColor DarkGray