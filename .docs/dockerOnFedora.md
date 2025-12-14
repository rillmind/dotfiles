# Docker on fedora

O docker no fedora pode apresentar um problema ao ser instalado que o impossibilita de iniciar o serviço no systemd. O problema é com o novo firewall do fedora que bloqueia algo que o docker precisa. A solução para isso é:

```sh
mkdir /etc/docker
sudo nano /etc/docker/daemon.json
```

```json
{
  "iptables": false
}
```

```sh
sudo systemctl restart docker
```
