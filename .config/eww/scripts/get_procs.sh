#!/bin/bash

get_cpu() {
    # Lista top 3 processos por CPU: Nome e %
    ps -eo comm,%cpu --sort=-%cpu | head -n 4 | tail -n 3 | awk '{print "{\"name\": \"" $1 "\", \"value\": \"" $2 "%\"}"}' | jq -s '.'
}

get_mem() {
    # Lista top 3 processos por RAM: Nome e valor
    ps -eo comm,rss --sort=-rss | head -n 4 | tail -n 3 | awk '{printf "{\"name\": \"%s\", \"value\": \"%.1f MiB\"}\n", $1, $2/1024}' | jq -s '.'
}

if [ "$1" == "cpu" ]; then
    get_cpu
elif [ "$1" == "mem" ]; then
    get_mem
fi
