# Mantém só os 2 kernels mais recentes (independe do installonly_limit do dnf.conf)
NAME="Kernels"
REQUIRES=(dnf)

pending() {
    dnf repoquery --installed --installonly --latest-limit=-2 -q
}

update() {
    sudo dnf remove -y $(pending)
}
