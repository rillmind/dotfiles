NAME="Homebrew"
REQUIRES=(brew)

pending() {
    brew outdated --verbose
}

update() {
    brew upgrade --yes
}
