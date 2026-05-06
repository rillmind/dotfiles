#!/bin/bash
PROCESS="$1"
CMD="${@:2}"

if pgrep -x "$PROCESS" > /dev/null; then
    pkill -x "$PROCESS"
else
    $CMD &
fi
