#!/usr/bin/env bash
# Atualiza o sistema (dnf, flatpak, brew, cargo, uv) e mantém só os 2 kernels mais recentes.
#   sysupdate      -> pergunta uma vez antes de cada atualizador
#   sysupdate -y   -> aceita tudo automaticamente
# Depois da confirmação (ou com -y), os atualizadores rodam sem fazer perguntas próprias.

AUTO=0
[[ "$1" == "-y" || "$1" == "--yes" ]] && AUTO=1

bold=$'\e[1m'; green=$'\e[32m'; red=$'\e[31m'; yellow=$'\e[33m'; gray=$'\e[90m'; reset=$'\e[0m'
names=(); statuses=(); reasons=()
logdir=$(mktemp -d)
trap 'rm -rf "$logdir"' EXIT

export NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1

confirm() {
    (( AUTO )) && return 0
    local reply
    read -rp "${yellow}?${reset} $1 [S/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[SsYy] ]]
}

# Pega uma linha curta explicando a falha a partir do stderr do atualizador
failure_reason() {
    local log="$1" code="$2" line
    line=$(sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e 's/\r/\n/g' "$log" \
        | grep -iE 'error|erro|fail|falh|cannot|não |not found|denied|unable|conflict' \
        | grep -v '^\s*$' | tail -1 | sed -E 's/^\s+//')
    [[ -z "$line" ]] && line="saiu com código $code"
    (( ${#line} > 80 )) && line="${line:0:77}..."
    echo "$line"
}

run_step() {
    local name="$1"; shift
    local log="$logdir/${#names[@]}.log" code
    names+=("$name")
    echo
    echo "${bold}==> ${name}${reset}"
    if ! confirm "Atualizar ${name}?"; then
        echo "Pulado."
        statuses+=(skip); reasons+=("pulado pelo usuário")
        return
    fi
    "$@" < /dev/null 2> >(tee "$log" >&2)
    code=$?
    wait $!
    if (( code == 0 )); then
        statuses+=(ok); reasons+=("")
    else
        statuses+=(fail); reasons+=("$(failure_reason "$log" "$code")")
    fi
}

missing_step() {
    names+=("$1"); statuses+=(skip); reasons+=("$2 não instalado")
}

cargo_update() {
    if ! cargo install-update --version &>/dev/null; then
        cargo install cargo-update || return 1
    fi
    cargo install-update -a
}

remove_old_kernels() {
    local old
    old=$(dnf repoquery --installed --installonly --latest-limit=-2 -q 2>/dev/null)
    if [[ -z "$old" ]]; then
        echo "Nenhum kernel antigo para remover."
        return 0
    fi
    echo "Kernels/pacotes antigos que serão removidos:"
    echo "$old" | sed 's/^/  /'
    sudo dnf remove -y $old
}

# Pede a senha do sudo uma vez no início
sudo -v || exit 1

run_step "DNF"     sudo dnf upgrade -y
run_step "Flatpak" flatpak update -y --noninteractive
if command -v brew  &>/dev/null; then run_step "Homebrew" brew upgrade;          else missing_step "Homebrew" brew;  fi
if command -v cargo &>/dev/null; then run_step "Cargo"    cargo_update;          else missing_step "Cargo"    cargo; fi
if command -v uv    &>/dev/null; then run_step "uv tools" uv tool upgrade --all; else missing_step "uv tools" uv;    fi
run_step "Kernels" remove_old_kernels

echo
echo "${bold}──────── Resumo ────────${reset}"
any_fail=0
for i in "${!names[@]}"; do
    case "${statuses[$i]}" in
        ok)   printf "  ${green}✔ %-10s${reset} ok\n" "${names[$i]}" ;;
        skip) printf "  ${gray}– %-10s %s${reset}\n" "${names[$i]}" "${reasons[$i]}" ;;
        fail) printf "  ${red}✘ %-10s${reset} ${red}%s${reset}\n" "${names[$i]}" "${reasons[$i]}"; any_fail=1 ;;
    esac
done
exit $any_fail
