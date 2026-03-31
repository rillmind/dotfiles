#!/bin/bash

# Define variáveis
ZEN_DIR="/opt/zen-browser"
BIN_LINK="/usr/local/bin/zen-browser"
DESKTOP_ENTRY="/usr/share/applications/zen.desktop"

# 1. Obter a URL da última versão (Linux x86_64 Generic) via GitHub API
echo "Buscando a última versão no GitHub..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | grep "browser_download_url.*linux-x86_64.tar.bz2" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Erro ao encontrar a URL de download."
    exit 1
fi

# 2. Download e Extração
echo "Baixando Zen Browser..."
curl -L "$DOWNLOAD_URL" -o /tmp/zen-browser.tar.bz2

echo "Extraindo para $ZEN_DIR..."
sudo rm -rf "$ZEN_DIR"
sudo mkdir -p "$ZEN_DIR"
sudo tar -xjf /tmp/zen-browser.tar.bz2 -C /opt/

# O tar extrai para uma pasta chamada 'zen', vamos renomear para manter o padrão
sudo mv /opt/zen/* "$ZEN_DIR/"
sudo rm -rf /opt/zen

# 3. Criar Link Simbólico para o binário
sudo ln -sf "$ZEN_DIR/zen" "$BIN_LINK"

# 4. Criar o atalho (.desktop) para o GNOME/Menu
echo "Criando entrada no menu de aplicativos..."
sudo bash -c "cat > $DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Name=Zen Browser
Comment=Navegador focado em privacidade
Exec=$BIN_LINK
Icon=$ZEN_DIR/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

# 5. Limpeza
rm /tmp/zen-browser.tar.bz2

echo "Instalação concluída! Você já pode abrir o Zen Browser pelo menu."
