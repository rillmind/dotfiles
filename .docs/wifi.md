# Wifi usando nmcli

## Mostra as redes disponíveis para conectar

```sh
nmcli device wifi list
```

## Conecta na rede escolhida

```sh
nmcli device wifi connect "nome" password "senha"
```

## Mostrar redes conhecidas

```sh
nmcli connection show
```

## Excluir rede conhecida

```sh
nmcli connection delete "nome"
```

obs: Ou pode usar o UUID sem as aspas
