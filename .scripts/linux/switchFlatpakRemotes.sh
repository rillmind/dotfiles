#!/bin/sh

# Este script move todas as aplicações Flatpak instaladas em nível de usuário para nível de sistema.
# Ele fará o seguinte:
# 1. Listar todas as IDs de aplicações Flatpak instaladas em nível de usuário.
# 2. Para cada aplicação, tentar instalá-la em nível de sistema (usando 'flathub' como remoto padrão).
# 3. Se a instalação em sistema for bem-sucedida, desinstalar a versão de usuário.
# 4. Limpar runtimes e extensões Flatpak não utilizadas.

echo "Iniciando a migração de Flatpaks de usuário para sistema..."
echo "Certifique-se de que você tem o repositório 'flathub' configurado em nível de sistema."
echo "Você pode verificar com 'flatpak remotes'."
echo ""

# Verificar se o flathub está configurado em nível de sistema
if ! flatpak remotes | grep -q "flathub.*system"; then
    echo "Atenção: O repositório 'flathub' não parece estar configurado em nível de sistema."
    echo "Para garantir que as reinstalações funcionem, adicione-o com:"
    echo "sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    echo "Continuando, mas algumas instalações podem falhar se o remoto correto não estiver disponível."
    echo ""
fi

# Listar IDs de todas as aplicações Flatpak instaladas em nível de usuário
USER_FLATPAKS=$(flatpak list --user --columns=application | tail -n +2) # tail -n +2 para pular o cabeçalho

if [ -z "$USER_FLATPAKS" ]; then
    echo "Nenhuma aplicação Flatpak instalada em nível de usuário encontrada. Nada para migrar."
else
    echo "Aplicações Flatpak instaladas em nível de usuário a serem migradas:"
    echo "$USER_FLATPAKS"
    echo ""

    for app_id in $USER_FLATPAKS; do
        echo "Processando aplicação: $app_id"

        # 1. Tentar instalar a aplicação em nível de sistema
        echo "  Tentando instalar $app_id em nível de sistema..."
        # Usamos 'flathub' como remote. Você pode precisar ajustar isso
        # se seus Flatpaks de sistema vêm de outro remoto principal.
        # --or-update garante que, se já existir no sistema, ele apenas atualize.
        # -y para confirmar automaticamente.
        if sudo flatpak install --system flathub "$app_id" -y; then
            echo "  $app_id instalado/atualizado com sucesso em nível de sistema."

            # 2. Se a instalação em sistema foi bem-sucedida, desinstalar a versão de usuário
            echo "  Desinstalando a versão de usuário de $app_id..."
            if flatpak uninstall --user "$app_id" -y; then
                echo "  Versão de usuário de $app_id desinstalada com sucesso."
            else
                echo "  Falha ao desinstalar a versão de usuário de $app_id. Pode ser que ela já tenha sido removida ou haja um problema."
            fi
        else
            echo "  Falha ao instalar $app_id em nível de sistema. Pode ser que o aplicativo não esteja disponível no remoto 'flathub', ou houve outro erro."
            echo "  A versão de usuário de $app_id não foi removida."
        fi
        echo ""
    done
fi

echo "Migração de Flatpaks concluída."
echo "Limpando runtimes e extensões Flatpak não utilizadas (isso pode liberar espaço)..."
sudo flatpak uninstall --unused -y
flatpak uninstall --user --unused -y # Limpa os do usuário também

echo "Processo finalizado."
echo "Para verificar as instalações, execute: flatpak list --columns=name,application,origin,installation"

flatpak remote-delete --user flathub
flatpak remote-delete fedora
