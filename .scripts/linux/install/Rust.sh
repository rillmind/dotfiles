#!/bin/bash
packages=(
  bluetui
)

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

hash -r

cargo install "${packages[@]}"

hash -r
