#!/bin/bash

curl -L https://raw.githubusercontent.com/catppuccin/gnome-terminal/v1.0.0/install.py | python3 -

# Define o nome exato do perfil Catppuccin que você quer tornar padrão
# Certifique-se de que este nome corresponda exatamente ao "visible-name" no seu terminal.
# Por exemplo: 'Catppuccin Mocha', 'Catppuccin Frappe', 'Catppuccin Macchiato', 'Catppuccin Latte'
PROFILE_NAME="Catppuccin Mocha"

# --- Não é necessário editar a partir daqui ---

echo "Buscando o UUID para o perfil '$PROFILE_NAME'..."

# Lista todos os perfis e seus nomes visíveis, e filtra pelo nome desejado
# Pega o UUID da linha anterior ao nome do perfil
PROFILE_UUID=$(dconf dump /org/gnome/terminal/legacy/profiles:/ | \
               grep -B 1 "visible-name='${PROFILE_NAME}'" | \
               head -n 1 | \
               grep -oP '(?<=:).*(?=/)')

# Verifica se um UUID foi encontrado
if [ -z "$PROFILE_UUID" ]; then
    echo "Erro: Perfil '$PROFILE_NAME' não encontrado."
    echo "Verifique se o nome está correto (case-sensitive) e se o perfil existe no seu GNOME Terminal."
    echo "Perfis disponíveis:"
    dconf dump /org/gnome/terminal/legacy/profiles:/ | awk '/\[:/||/visible-name=/'
    exit 1
fi

echo "UUID encontrado para '$PROFILE_NAME': $PROFILE_UUID"

# Define o perfil encontrado como o padrão no GNOME Terminal
dconf write /org/gnome/terminal/legacy/profiles:/default "'${PROFILE_UUID}'"

echo "Perfil '$PROFILE_NAME' foi definido como o padrão para o GNOME Terminal."
echo "Para ver a mudança, feche e reabra suas janelas do terminal."
