# Nvidia driver instalation

## Dependências

```sh
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda kmodtool akmods mokutil openssl libva-nvidia-driver nvidia-vaapi-driver ffmpeg-libs
```

## Gere uma chave de assinatura 

```sh
sudo kmodgenca -a --force
```

## Importe a chave para o sistema

```sh
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

## Desativar o nouveau

```sh
sudo grubby --update-kernel=ALL --args="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1"
```

## Conferir se pode reiniciar o sistema

```sh
ps -ef | grep akmod | grep -v grep
```

- Se o comando retornar alguma linha: O sistema ainda está compilando. Não reinicie.
- Se o comando não retornar nada: A compilação terminou.

```sh
modinfo -F version nvidia
```

- Se aparecer a versão do driver (ex: 555.xx.xx), você pode reiniciar agora.

- Se aparecer uma mensagem de erro ("modinfo: ERROR: Module nvidia not found"), a compilação ainda não foi concluída ou falhou.

## Atualize o flatpak

```sh
flatpak update
```

- Procure por algo como org.freedesktop.Platform.GL.nvidia-580-126-18 na lista de atualizações.
