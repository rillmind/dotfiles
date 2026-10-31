NAME="uv tools"
REQUIRES=(uv)

pending() {
    uv tool list --outdated
}

update() {
    uv tool upgrade --all
}
