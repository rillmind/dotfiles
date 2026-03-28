# Configurando ACL

No sistema host, execute esse comando:

```sh
sudo setfacl -m u:$USER:rw /var/run/docker.sock
```

Depois disso, instale o docker, e o compose, no distrobox e teste.
