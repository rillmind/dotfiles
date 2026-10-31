NAME="Flatpak"
REQUIRES=(flatpak)

update() {
    if (( AUTO )); then
        flatpak update -y --noninteractive
    else
        flatpak update
    fi
}
