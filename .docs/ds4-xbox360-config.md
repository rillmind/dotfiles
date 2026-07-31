# Configuração: DualShock 4 → Xbox 360 via InputPlumber (Fedora Linux)

## Objetivo

Fazer com que o controle **DualShock 4 (PS4)** conectado via Bluetooth seja reconhecido pelo sistema e jogos como um **controle Xbox 360**.

---

## Visão Geral da Solução

**InputPlumber** (v0.77.7) é usado para criar um *composite device* virtual que emula um Xbox 360 pad a partir dos inputs do DS4 real. O DS4 original é escondido das aplicações para evitar conflitos.

> Alternativa descartada: `ds4drv` foi corrigido mas mostrou-se instável no Python 3.14 e foi substituído pelo InputPlumber como solução principal.

---

## Arquivos de Configuração Criados/Modificados

### 1. `/etc/inputplumber/devices.d/60-ps4_gamepad.yaml`

**Override** que substitui a config original de fábrica (`/usr/share/inputplumber/devices/60-ps4_gamepad.yaml`).

**Conteúdo final:**

```yaml
version: 1
kind: CompositeDevice
name: Sony Interactive Entertainment Wireless Controller
maximum_sources: 4
matches: []
source_devices:
  - group: gamepad
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input
    capability_map_id: swap_west_north
    config:
      led:
        fixed_color:
          r: 255
          g: 0
          b: 40

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller Motion Sensors"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller Touchpad"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: idVendor
          value: "054c"
        - name: idProduct
          value: "{09cc,05c4}"
      subsystem: hidraw

target_devices:
  - xb360
```

**Mudanças chave em relação ao original:**
| Atributo | Original | Modificado |
|---|---|---|
| `target_devices` | `ds5` | `xb360` |
| Sensor de movimento | — | `blocked: true` |
| Touchpad | — | `blocked: true` |
| Hidraw | — | `blocked: true` |
| LED fixo | — | `r: 255, g: 0, b: 40` (vermelho rosado) |

### 2. `/etc/systemd/system/inputplumber.service.d/hide.conf`

Drop-in do systemd para esconder os dispositivos originais do DS4 das aplicações:

```ini
[Service]
Environment=HIDE_DEVICES_FROM_ROOT=1
```

### 3. `/etc/udev/rules.d/52-ds4drv.rules` (não aplicado)

Regra udev para dar acesso ao hidraw sem root (criada durante a tentativa com `ds4drv`, mas não chegou a ser aplicada de fato):

```
SUBSYSTEM=="input", ATTRS{name}=="Sony Computer Entertainment Wireless Controller", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
```

---

## Alterações em `ds4drv` (código Python)

Três correções foram feitas nos fontes do `ds4drv` para compatibilidade com Python 3.14 (que estava rodando no sistema):

### a) `config.py` — `SafeConfigParser` removido

- **Problema:** `SafeConfigParser` foi removido no Python 3.12+.
- **Correção:** Substituído por `ConfigParser` (linhas 72 e 99).

### b) `config.py` — Referência circular causa `RecursionError`

- **Problema:** Python 3.14 itera todos atributos no `__repr__` do `argparse.Namespace`. O atributo `parent` criava uma referência circular (`controller → options → controller`), causando recursão infinita.
- **Correção:** Substituída a referência `controller.parent = options` por `controller._bindings = options.bindings` (removendo o atributo `parent` que causava o ciclo).

### c) `actions/input.py` — `InputDevice.fn` removido

- **Problema:** A propriedade `.fn` foi removida na nova versão do `evdev`.
- **Correção:** Substituída por `.path`.

### d) `backends/bluetooth.py` — `hcitool` removido do BlueZ

- **Problema:** `hcitool` foi removido do BlueZ 5.77+.
- **Correção:** Backend bluetooth modificado para usar D-Bus (`bluetoothctl`) como fallback quando `hcitool` não está disponível.

---

## Comandos Úteis (para refazer a configuração)

### Verificar se o InputPlumber está rodando

```bash
systemctl status inputplumber
```

### Ativar gerenciamento de todos os devices

```bash
sudo inputplumber devices manage-all --enable
```

### Listar devices gerenciados

```bash
sudo inputplumber devices list
```

### Ver informações de um device específico

```bash
sudo inputplumber device 0 info
```

### Ver logs do InputPlumber

```bash
journalctl -u inputplumber --no-pager -n 50
```

### Recarregar regras udev

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Mudar a cor do LED (temporário)

```bash
# Vermelho com toque rosado (R=255, G=0, B=40)
echo 255 | sudo tee /sys/class/leds/input61:red/brightness
echo 0   | sudo tee /sys/class/leds/input61:green/brightness
echo 40  | sudo tee /sys/class/leds/input61:blue/brightness

# Azul (R=0, G=0, B=255)
echo 0   | sudo tee /sys/class/leds/input61:red/brightness
echo 0   | sudo tee /sys/class/leds/input61:green/brightness
echo 255 | sudo tee /sys/class/leds/input61:blue/brightness
```

> Nota: o número `input61` pode variar. Descubra qual é com:
> ```bash
> ls /sys/class/leds/ | grep -i ".*:red$"
> ```

---

## Fluxo completo de configuração do zero

```bash
# 1. Garantir que o InputPlumber está instalado e rodando
sudo systemctl enable --now inputplumber

# 2. Criar diretório para overrides
sudo mkdir -p /etc/inputplumber/devices.d

# 3. Copiar o arquivo de config (substitua pelo YAML acima)
sudo cp 60-ps4_gamepad.yaml /etc/inputplumber/devices.d/

# 4. Criar drop-in do systemd para esconder devices originais
sudo mkdir -p /etc/systemd/system/inputplumber.service.d
printf "[Service]\nEnvironment=HIDE_DEVICES_FROM_ROOT=1\n" | sudo tee /etc/systemd/system/inputplumber.service.d/hide.conf
sudo systemctl daemon-reload

# 5. Reiniciar o serviço
sudo systemctl restart inputplumber

# 6. Ativar gerenciamento de todos os devices
sudo inputplumber devices manage-all --enable

# 7. Conectar o DS4 via Bluetooth e testar
# O LED do controle deve acender na cor configurada (vermelho rosado)
# O sistema deve mostrar um "Microsoft X-Box 360 pad"
cat /proc/bus/input/devices | grep -E "Name=|Handlers=" | paste - - | grep -i xbox
```

---

## Problemas Enfrentados e Soluções

| Problema | Causa | Solução |
|---|---|---|
| `ds4drv` não abre | `SafeConfigParser` removido no Python 3.12+ | Substituir por `ConfigParser` |
| `ds4drv` recursão infinita | Referência circular `parent` no `__repr__` do Python 3.14 | Remover `parent`, usar `_bindings` |
| `ds4drv` erro `fn` não encontrado | Propriedade `.fn` removida do `evdev` | Usar `.path` |
| `ds4drv` erro `hcitool` | `hcitool` removido do BlueZ 5.77 | Migrar backend para D-Bus |
| Jogo não reconhece o controle | DS4 original visível para SDL/evdev | Ativar `HIDE_DEVICES_FROM_ROOT=1` |
| Personagem andando sozinho | Sensores de movimento do DS4 mapeados como analógicos do Xbox | `blocked: true` nos Motion Sensors |
| Touchpad interfere | Touchpad do DS4 mandando eventos | `blocked: true` no Touchpad |
| LED do controle não acende | InputPlumber não controla LED com target `xb360` | Escrever direto no sysfs |
| `sudo inputplumber devices list` vazio | `manage-all` não foi ativado | Rodar `sudo inputplumber devices manage-all --enable` |

---

## Notas Finais

- O InputPlumber é a solução **recomendada** — é mais estável que o `ds4drv` e se integra melhor com o sistema.
- O `ds4drv` foi corrigido apenas a título de diagnóstico; seu uso não é recomendado em produção.
- A configuração documentada aqui persiste entre reboots e reconexões do Bluetooth.
- Os valores de LED via sysfs **não persistem** após desconectar/reconectar o controle. Para persistência, seria necessário criar uma regra udev. Mas o `config.led.fixed_color` do YAML deste override é aplicado pelo InputPlumber ao criar o composite device.
