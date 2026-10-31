#!/usr/bin/env bash
# Atualiza o sistema rodando cada módulo de sysupdate.d/ em ordem de nome.
#   sysupdate.sh      -> mostra o que será atualizado e pergunta em cada etapa ([S/n], Enter = sim)
#   sysupdate.sh -y   -> aceita tudo automaticamente
#
# Interface de um módulo (sysupdate.d/NN-nome.sh):
#   NAME="Homebrew"     obrigatório: nome exibido no output e no resumo
#   REQUIRES=(brew)     opcional: comandos necessários; se faltar algum, o módulo é pulado
#   pending() { ... }   opcional: imprime o que será atualizado (saída vazia = nada a fazer).
#                       Se existir, o núcleo mostra a lista e pergunta [S/n].
#                       Se não existir, o módulo usa o prompt nativo da ferramenta.
#   update()  { ... }   obrigatório: faz a atualização. Com AUTO=1 (modo -y) não deve perguntar nada.
# Helpers para os módulos: $AUTO (0/1) e yes_flag (imprime "-y" quando AUTO=1).
#
# Dependência opcional: `script` (Fedora: util-linux-script). Com ele, tudo roda num pseudo-terminal
# gravado em log: as ferramentas mantêm barras de progresso e prompts normais e o resumo mostra o
# motivo das falhas. Sem ele, roda direto e o motivo vira só o código de saída.

AUTO=0
[[ "$1" == "-y" || "$1" == "--yes" ]] && AUTO=1

# Reexecuta o script inteiro dentro de um único `script`, gravando a sessão em SYSUPDATE_LOG.
# Um terminal só para tudo: o sudo pede a senha uma vez e o visual das ferramentas não quebra.
if [[ -z "$SYSUPDATE_LOG" ]] && command -v script &>/dev/null; then
    export SYSUPDATE_LOG=$(mktemp)
    SHELL=/bin/bash script -qefc "$(printf '%q ' "$(readlink -f "$0")" "$@")" "$SYSUPDATE_LOG"
    code=$?
    rm -f "$SYSUPDATE_LOG"
    exit $code
fi

MODULE_DIR="${SYSUPDATE_DIR:-$(dirname "$(readlink -f "$0")")/sysupdate.d}"

bold=$'\e[1m'; green=$'\e[32m'; red=$'\e[31m'; yellow=$'\e[33m'; gray=$'\e[90m'; reset=$'\e[0m'
names=(); statuses=(); reasons=()
logdir=$(mktemp -d)
trap 'rm -rf "$logdir"' EXIT

export NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1

yes_flag() { (( AUTO )) && echo "-y"; }

confirm() {
    (( AUTO )) && return 0
    local reply
    read -rp "${yellow}?${reset} $1 [S/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[SsYy] ]]
}

record() { names+=("$1"); statuses+=("$2"); reasons+=("$3"); }

clean_log() { sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e 's/\r/\n/g' "$1"; }

# Pega uma linha curta explicando a falha a partir do stderr do atualizador
failure_reason() {
    local log="$1" code="$2" line
    line=$(clean_log "$log" \
        | grep -iE 'error|erro|fail|falh|cannot|não |not found|denied|unable|conflict' \
        | grep -v '^\s*$' | tail -1 | sed -E 's/^\s+//')
    [[ -z "$line" ]] && line="saiu com código $code"
    (( ${#line} > 80 )) && line="${line:0:77}..."
    echo "$line"
}

run_module() {
    local file="$1" log="$logdir/${#names[@]}.log" list code cmd

    unset NAME REQUIRES
    unset -f pending update
    source "$file"

    if [[ -z "$NAME" ]] || ! declare -F update &>/dev/null; then
        record "$(basename "$file" .sh)" fail "módulo inválido: falta NAME ou update()"
        return
    fi

    echo
    echo "${bold}==> ${NAME}${reset}"

    for cmd in "${REQUIRES[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Pulado: $cmd não instalado."
            record "$NAME" skip "$cmd não instalado"
            return
        fi
    done

    if declare -F pending &>/dev/null; then
        list=$(pending 2>/dev/null)
        if [[ -z "$list" ]]; then
            echo "Nada para atualizar."
            record "$NAME" skip "nada para atualizar"
            return
        fi
        echo "$list" | sed 's/^/  /'
        if ! confirm "Atualizar ${NAME}?"; then
            echo "Pulado."
            record "$NAME" skip "pulado pelo usuário"
            return
        fi
    fi

    # Sem pipes: a ferramenta escreve direto no terminal. O trecho do log da sessão gerado
    # durante o update vira o log deste módulo.
    local start=0
    [[ -n "$SYSUPDATE_LOG" ]] && start=$(stat -c %s "$SYSUPDATE_LOG")
    update
    code=$?
    if [[ -n "$SYSUPDATE_LOG" ]]; then
        tail -c +$((start + 1)) "$SYSUPDATE_LOG" > "$log"
    else
        : > "$log"
    fi

    if (( code == 0 )); then
        record "$NAME" ok ""
    elif clean_log "$log" | grep -qiE 'abort|cancel'; then
        record "$NAME" skip "cancelado pelo usuário"
    else
        record "$NAME" fail "$(failure_reason "$log" "$code")"
    fi
}

shopt -s nullglob
modules=("$MODULE_DIR"/*.sh)
if (( ${#modules[@]} == 0 )); then
    echo "${red}Nenhum módulo encontrado em ${MODULE_DIR}${reset}"
    exit 1
fi

# Pede a senha do sudo uma vez no início
sudo -v || exit 1

for module in "${modules[@]}"; do
    run_module "$module"
done

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
