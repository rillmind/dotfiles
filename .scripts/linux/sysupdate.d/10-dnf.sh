NAME="DNF"
REQUIRES=(dnf)

update() {
    sudo dnf upgrade --setopt=defaultyes=True $(yes_flag)
}
