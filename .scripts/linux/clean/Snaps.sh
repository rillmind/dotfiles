#!/bin/bash
set -eu
snap list --all | awk '/disabled/{print $1, $3, $5}' |
while read snapname revision state; do
   sudo snap remove "$snapname" --revision="$revision"
done
