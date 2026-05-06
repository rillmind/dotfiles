#!/bin/bash

get_cpu() {
    ps -eo comm,%cpu --sort=-%cpu | head -n 4 | tail -n 3 | awk '{
        gsub(/"/, "\\\"", $1)
        printf "%s{\"name\": \"%s\", \"value\": \"%s%%\"}", sep, $1, $2
        sep = ","
    } END {print "]"}' | sed 's/^/[/'
}

get_mem() {
    ps -eo comm,rss --sort=-rss | head -n 4 | tail -n 3 | awk '{
        gsub(/"/, "\\\"", $1)
        printf "%s{\"name\": \"%s\", \"value\": \"%.1f MiB\"}", sep, $1, $2/1024
        sep = ","
    } END {print "]"}' | sed 's/^/[/'
}

if [ "$1" == "cpu" ]; then
    get_cpu
elif [ "$1" == "mem" ]; then
    get_mem
fi