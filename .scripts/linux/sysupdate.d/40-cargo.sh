NAME="Cargo"
REQUIRES=(cargo)

pending() {
    if ! cargo install-update --version &>/dev/null; then
        echo "cargo-update (não instalado, será instalado)"
        return
    fi
    cargo install-update -l | awk '$NF == "Yes" { print $1, $2, "->", $3 }'
}

update() {
    if ! cargo install-update --version &>/dev/null; then
        cargo install cargo-update || return 1
    fi
    cargo install-update -a
}
