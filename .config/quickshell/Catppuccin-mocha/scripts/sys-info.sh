#!/bin/sh
# Imprime um JSON (uma linha) com CPU, memória, GPU, rede e top processos para o painel do sistema.
export LANGUAGE=C LC_ALL=C

# CPU: temperatura do pacote, frequência média, load average
cpu_temp=""
for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = "coretemp" ]; then
        cpu_temp=$(( $(cat "$h/temp1_input") / 1000 ))
        break
    fi
done
cpu_freq=$(awk -F: '/^cpu MHz/ { s += $2; n++ } END { if (n) printf "%d", s / n }' /proc/cpuinfo)
read -r load1 load5 load15 _ < /proc/loadavg
cpu_name=$(awk -F': ' '/^model name/ { print $2; exit }' /proc/cpuinfo | sed 's/([^)]*)//g; s/  */ /g')
cores=$(nproc)

# Memória (kB)
eval "$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ { gsub(":", "", $1); print $1 "=" $2 }' /proc/meminfo)"

# GPU NVIDIA: só consulta se já estiver acordada (nvidia-smi acorda a dGPU e gasta bateria)
gpu='null'
for d in /sys/bus/pci/drivers/nvidia/0000:*; do
    [ -e "$d" ] || continue
    if [ "$(cat "$d/power/runtime_status" 2>/dev/null)" = "suspended" ]; then
        gpu='{"sleeping":true}'
    elif command -v nvidia-smi >/dev/null; then
        gpu=$(timeout 3 nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
              --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{
              printf "{\"sleeping\":false,\"name\":\"%s\",\"util\":%d,\"memUsed\":%d,\"memTotal\":%d,\"temp\":%d,\"power\":%.1f}", $1, $2, $3, $4, $5, $6 }')
        [ -n "$gpu" ] || gpu='null'
    fi
    break
done

# Rede: bytes recebidos/enviados da interface padrão (a velocidade é calculada no QML)
iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
rx=0; tx=0
if [ -n "$iface" ]; then
    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
fi

# Top processos por CPU (segunda amostra do top = uso atual, não média desde o início)
procs=$(top -b -n 2 -d 0.5 -o %CPU -w 512 2>/dev/null | awk '
    /^top -/ { frame++ }
    frame == 2 && /^ *PID/ { on = 1; next }
    frame == 2 && on && NF >= 12 && n < 6 {
        cmd = $12; gsub(/["\\]/, "", cmd)
        printf "%s{\"pid\":%d,\"name\":\"%s\",\"cpu\":%.1f,\"mem\":%.1f}", (n ? "," : ""), $1, cmd, $9, $10
        n++
    }')

printf '{"cpu":{"name":"%s","cores":%d,"temp":%s,"freq":%s,"load":[%s,%s,%s]},' \
    "$cpu_name" "$cores" "${cpu_temp:-null}" "${cpu_freq:-null}" "$load1" "$load5" "$load15"
printf '"mem":{"total":%d,"available":%d,"swapTotal":%d,"swapFree":%d},' \
    "$MemTotal" "$MemAvailable" "$SwapTotal" "$SwapFree"
printf '"gpu":%s,"net":{"iface":"%s","rx":%s,"tx":%s},"procs":[%s]}\n' \
    "$gpu" "$iface" "$rx" "$tx" "$procs"
