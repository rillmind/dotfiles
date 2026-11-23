#!/usr/bin/env pwsh

Write-Host "Ligando as configurações do GlazeWM e do YASB ao dotfiles..." -ForegroundColor Cyan

# Links simbólicos por arquivo (os logs dos dois ficam fora do repositório).
# Precisa do Modo Desenvolvedor ativado, ou rodar como administrador.
$repo = "$HOME\dotfiles\.config\Windows"
$links = @{
  "$HOME\.glzr\glazewm\config.yaml" = "$repo\glazewm\config.yaml"
  "$HOME\.config\yasb\config.yaml"  = "$repo\yasb\config.yaml"
  "$HOME\.config\yasb\styles.css"   = "$repo\yasb\styles.css"
}

foreach ($dest in $links.Keys) {
  $source = $links[$dest]
  $destDir = Split-Path $dest
  if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

  New-Item -ItemType SymbolicLink -Path $dest -Target $source -Force | Out-Null
  Write-Host "Link criado: $dest -> $source" -ForegroundColor Green
}
