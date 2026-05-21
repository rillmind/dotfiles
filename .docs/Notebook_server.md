# Desativar suspensão de notebook com linux server

## Hibernação no logind.conf

### Edita o arquivo /etc/systemd/logind.conf:

```bash
sudo nano /etc/systemd/logind.conf
```

### Procura a linha HandleLidSwitch e deixa assim:

```ini
iniHandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
```

As três cobrem os casos: bateria, carregando, e conectado a dock/monitor externo.

### Depois reinicia o serviço:

```bash
sudo systemctl restart systemd-logind
```

## Hibernação via systemd

Além do `logind.conf`, você precisa também desabilitar o suspend/hibernate completamente.

### Desabilita os targets de sleep/suspend/hibernate:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### Reinicia o logind:

```bash
sudo systemctl restart systemd-logind
```

O `mask` é mais forte que `disable` — ele bloqueia qualquer coisa de acionar o suspend, mesmo que outro serviço tente. O CasaOS não vai mais cair.
