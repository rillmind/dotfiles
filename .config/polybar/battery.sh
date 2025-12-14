#!/bin/bash

# Coloque aqui o local que identifica sem seu dispositivo está carregando ou descarregando
# IMPORTANTE ! A saída deve ser em binário, caso contrário resultará em erro!
is_plugged=$(cat /sys/class/power_supply/AC/online)

# Coloque aqui o local que identifica o número relativo a porcentagem da bateria de seu dispositivo
battery_level=$(cat /sys/class/power_supply/BAT0/capacity)

# EXTRA! Altere os ícones para qualquer um de sua preferência, assim como os valores da %
# EXTRA! Customize a cor do ícone começando com %{F#} e fechando com %{F-}
if [ "$is_plugged" -eq 1 ]; then
  icon="%{F#F0C674}%{F-}"
else
  if [ "$battery_level" -le 15 ]; then
    icon="%{F#F0C674}%{F-}"
  elif [ "$battery_level" -le 25 ]; then
    icon="%{F#F0C674}%{F-}"
  elif [ "$battery_level" -le 60 ]; then
    icon="%{F#F0C674}%{F-}"
  elif [ "$battery_level" -le 90 ]; then
    icon="%{F#F0C674}%{F-}"
  else
    icon="%{F#F0C674}%{F-}"
  fi
fi

echo " $battery_level% $icon"
