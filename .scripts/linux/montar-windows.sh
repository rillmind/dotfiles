#!/bin/bash

# isso funciona no Fedora 44 em julho de 2026 no setup atual.

sudo mkdir -p /run/media/raul/Windows

sudo mount -t ntfs-3g /dev/nvme0n1p2 /
