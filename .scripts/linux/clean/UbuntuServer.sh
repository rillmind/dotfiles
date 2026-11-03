#!/usr/bin/env bash
# ==============================================================================
#  UbuntuServer.sh – limpeza do servidor (server-ubuntu, Ubuntu 26.04 + Docker + CasaOS)
#
#  Instalado no servidor como: /usr/local/sbin/server-clean
#  Fonte versionada em:        ~/dotfiles/.scripts/linux/clean/UbuntuServer.sh
#
#  Uso (no servidor):
#    sudo server-clean             limpa tudo o que é seguro
#    sudo server-clean --builds    também apaga pastas de build (target/ do Rust em ~/dev)
#    sudo server-clean --dry-run   só mostra o que seria limpo, sem apagar nada
#    sudo server-clean --help      esta ajuda
#
#  Do PC (via Tailscale):
#    ssh -t raul@100.74.171.65 sudo server-clean
#
#  O que limpa:
#    1. APT: cache de pacotes baixados e pacotes órfãos (autoremove --purge)
#    2. Logs: journal reduzido a 500 MB e remove logs antigos já rotacionados (*.1, *.gz)
#    3. Snap: revisões antigas desativadas
#    4. Docker: imagens sem nenhum container usando, cache de build e logs de container
#       maiores que 50 MB (zerados). Garante o limite de log 10 MB × 3 no daemon.json.
#    5. Usuário (quem chamou o sudo): caches do Bun e do npm, lixeira e, com --builds,
#       as pastas target/ dos projetos em ~/dev
#
#  O que NUNCA mexe:
#    - Volumes do Docker e /DATA (mídia, Nextcloud, Kavita, AppData do CasaOS)
#    - Containers (parados ou rodando) e as imagens que eles usam
#    - Arquivos pessoais na home (Downloads, Documentos, código-fonte)
#
#  Observação: o limite de log do daemon.json só vale para containers criados depois
#  dele. Containers antigos continuam sem limite até serem recriados (ex.: atualizar o
#  app no CasaOS) – por isso o passo 4 também zera os logs grandes deles.
# ==============================================================================

set -uo pipefail

DRY_RUN=0
BUILDS=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --builds)  BUILDS=1 ;;
        -h|--help) sed -n '2,/^# =====/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opção desconhecida: $arg (veja --help)"; exit 2 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo $0 $*"
    exit 1
fi

USER_NAME="${SUDO_USER:-root}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

bold=$'\e[1m'; green=$'\e[32m'; yellow=$'\e[33m'; cyan=$'\e[36m'; gray=$'\e[90m'; reset=$'\e[0m'

section() { echo; echo "${bold}${cyan}==> $1${reset}"; }

# run "descrição" comando...  – executa, ou só descreve no --dry-run
run() {
    local desc="$1"; shift
    if (( DRY_RUN )); then
        echo "${gray}[dry-run]${reset} $desc"
    else
        echo "${green}•${reset} $desc"
        "$@"
    fi
}

size_of() { du -sh "$@" 2>/dev/null | awk '{ s = s (s ? " " : "") $1 } END { print s }'; }

used_before=$(df --output=used -B1 / | tail -1)

# ── 1. APT ───────────────────────────────────────────────────────────────────
section "APT"
run "cache de pacotes ($(size_of /var/cache/apt/archives))" apt-get clean
run "pacotes órfãos" apt-get autoremove --purge -y

# ── 2. Logs ──────────────────────────────────────────────────────────────────
section "Logs"
run "journal: reduzir para 500 MB (hoje: $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]'))" \
    journalctl --vacuum-size=500M
old_logs=$(find /var/log -type f \( -name '*.gz' -o -regex '.*\.[0-9]+' \) 2>/dev/null)
if [ -n "$old_logs" ]; then
    run "logs antigos rotacionados ($(echo "$old_logs" | xargs -d '\n' du -ch 2>/dev/null | tail -1 | cut -f1))" \
        xargs -d '\n' rm -f <<< "$old_logs"
else
    echo "${gray}nenhum log rotacionado${reset}"
fi

# ── 3. Snap ──────────────────────────────────────────────────────────────────
section "Snap"
if command -v snap >/dev/null; then
    disabled=$(LANG=C snap list --all 2>/dev/null | awk '/disabled/ { print $1 " " $3 }')
    if [ -n "$disabled" ]; then
        while read -r name rev; do
            run "remover $name (revisão $rev)" snap remove "$name" --revision="$rev"
        done <<< "$disabled"
    else
        echo "${gray}nenhuma revisão antiga${reset}"
    fi
fi

# ── 4. Docker ────────────────────────────────────────────────────────────────
section "Docker"
if command -v docker >/dev/null; then
    run "imagens sem uso + cache de build (recuperável: $(docker system df --format '{{.Type}} {{.Reclaimable}}' | awk '/Images/ { print $2 }'))" \
        sh -c 'docker image prune -af >/dev/null && docker builder prune -af >/dev/null'

    big_logs=$(find /var/lib/docker/containers -name '*-json.log' -size +50M 2>/dev/null)
    if [ -n "$big_logs" ]; then
        while read -r log; do
            id=$(basename "$(dirname "$log")")
            name=$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null | tr -d /)
            run "zerar log do container ${name:-$id} ($(size_of "$log"))" truncate -s 0 "$log"
        done <<< "$big_logs"
    else
        echo "${gray}nenhum log de container acima de 50 MB${reset}"
    fi

    # limite de log para containers novos (não sobrescreve um daemon.json existente)
    if [ ! -f /etc/docker/daemon.json ]; then
        run "criar /etc/docker/daemon.json com limite de log 10 MB × 3 e reiniciar o Docker" \
            sh -c 'printf "%s\n" "{" "  \"log-driver\": \"json-file\"," "  \"log-opts\": { \"max-size\": \"10m\", \"max-file\": \"3\" }" "}" > /etc/docker/daemon.json && systemctl restart docker'
    elif ! grep -q '"max-size"' /etc/docker/daemon.json; then
        echo "${yellow}! /etc/docker/daemon.json existe sem limite de log – adicione \"log-opts\": {\"max-size\": \"10m\", \"max-file\": \"3\"}${reset}"
    else
        echo "${gray}limite de log já configurado${reset}"
    fi
fi

# ── 5. Usuário ───────────────────────────────────────────────────────────────
section "Usuário ($USER_NAME)"
for dir in "$USER_HOME/.bun/install/cache" "$USER_HOME/.npm/_cacache" "$USER_HOME/.cache/pip" "$USER_HOME/.local/share/Trash/files"; do
    [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ] && run "${dir#$USER_HOME/} ($(size_of "$dir"))" rm -rf "$dir"
done
if (( BUILDS )); then
    while read -r target; do
        [ -f "$(dirname "$target")/Cargo.toml" ] || continue
        run "build do Rust: ${target#$USER_HOME/} ($(size_of "$target"))" rm -rf "$target"
    done < <(find "$USER_HOME/dev" -maxdepth 3 -type d -name target 2>/dev/null)
else
    echo "${gray}pastas de build mantidas (use --builds para apagar)${reset}"
fi

# ── Resumo ───────────────────────────────────────────────────────────────────
section "Resumo"
used_after=$(df --output=used -B1 / | tail -1)
freed=$(( used_before - used_after ))
(( DRY_RUN )) && echo "Nada foi apagado (--dry-run)." || echo "Liberado: ${bold}$(numfmt --to=iec "$freed")${reset}"
df -h / | tail -1 | awk '{ print "Disco: " $3 " usados de " $2 " (" $5 "), " $4 " livres" }'
