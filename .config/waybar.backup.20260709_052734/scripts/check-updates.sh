#!/bin_sh

# -q (quiet) para saída limpa, -C para usar cache se possível (mais rápido)
updates=$(sudo dnf check-upgrade -q -C | wc -l)

if [ "$updates" -gt 0 ]; then
    echo $updates
else
    echo ""
fi
