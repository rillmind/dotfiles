#!/usr/bin/env bash
# brew-maintain.sh — manutenção simples do Homebrew (Linuxbrew)
# Uso: ./brew-maintain.sh

set -euo pipefail

if ! command -v brew &>/dev/null; then
    echo "brew não encontrado no PATH. Abortando."
    exit 1
fi

echo ""
echo "==> Atualizando Homebrew..."
brew update

echo ""
echo "==> Verificando pacotes desatualizados..."
brew outdated || true

echo ""
echo "==> Fazendo upgrade dos pacotes..."
brew upgrade

echo ""
echo "==> Removendo dependências órfãs (autoremove)..."
brew autoremove

echo ""
echo "==> Limpando cache e versões antigas (cleanup)..."
# -s também limpa a cache de downloads de source/bottle
brew cleanup -s

echo ""
echo "==> Rodando diagnóstico (doctor)..."
brew doctor || true

echo ""
echo "==> Espaço ocupado pelo cache do brew:"
du -sh "$(brew --cache)" 2>/dev/null || echo "  (cache vazio ou inacessível)"

echo ""
echo "==> Concluído."
