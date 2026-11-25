#!/usr/bin/env python3
"""Barra lateral do tmux: um painel vazio (sem processo) de 3 colunas à esquerda de cada aba, com o
número de cada aba num quadrado e o servidor (sessão) embaixo. Ver lateral.conf.

  lateral.py sync              cria/ajusta/redesenha as barras (chamado pelos hooks)
  lateral.py clique Y SESSAO   vai para a aba desenhada na linha Y
  lateral.py desligar          remove as barras e volta para a barra do topo
  lateral.py alternar          troca entre lateral e topo e guarda a escolha (Ctrl+Shift+B)
  lateral.py usar BARRA        muda para "lateral" ou "topo" e guarda (o aparencia.sh chama a cada tema)
  lateral.py inicio            liga a lateral se for a escolha guardada (chamado pelo .tmux.conf)
"""
import fcntl
import functools
import os
import subprocess
import sys

LARG = 3

HOOKS = ("window-linked window-unlinked window-resized session-created session-renamed "
         "session-window-changed window-pane-changed pane-exited alert-bell alert-activity "
         "after-kill-pane after-swap-window after-move-window after-resize-pane after-select-layout").split()


def tmux(*a, entrada=None):
    return subprocess.run(("tmux",) + a, input=entrada, capture_output=True, text=True).stdout


def linhas(*a):
    return [l.split("\t") for l in tmux(*a).splitlines()]


@functools.lru_cache(None)
def rgb(op, fundo=False):
    h = tmux("show", "-gv", op).strip().lstrip("#")
    return "\033[%d;2;%d;%d;%dm" % (48 if fundo else 38, *(int(h[i:i + 2], 16) for i in (0, 2, 4)))


@functools.lru_cache(None)
def bordas():
    """(esq, dir) do quadrado, da metade de cima e da de baixo do bloco do servidor; @cantos vem do tema."""
    base = 0xF8E8 if tmux("show", "-gqv", "@cantos").strip() == "retos" else 0xF8E2
    return [chr(base + i) for i in range(6)]


def quadrado(texto, cor):
    f = rgb("@thm_mantle", True) + rgb(cor)
    if len(texto) == 1 and texto.isdigit():     # algarismo vazado no glifo (fonte Tmux Lateral)
        e, d = bordas()[:2]
        return f"{f}{e}{chr(0xF8D0 + int(texto))}{d}\033[0m"
    return f"{f}\033[1m{texto[:3]:^3}\033[0m"    # 10 em diante e sessões com nome: só o texto


def abas_de(sessao):
    return linhas("list-windows", "-t", sessao, "-F", "#{window_index}\t#{window_id}\t#{window_bell_flag}\t#{window_activity_flag}")


def paineis():
    janelas = {}
    for s, w, zoom, p, barra, ativo, x, h, nome in linhas(
            "list-panes", "-a", "-F",
            "#{session_id}\t#{window_id}\t#{window_zoomed_flag}\t#{pane_id}\t#{@barra}\t#{pane_active}\t"
            "#{pane_width}\t#{pane_height}\t#{session_name}"):
        j = janelas.setdefault(w, {"s": s, "nome": nome, "zoom": zoom == "1", "barras": [], "reais": []})
        (j["barras"] if barra == "1" else j["reais"]).append(
            {"id": p, "ativo": ativo == "1", "x": int(x), "h": int(h)})
    return janelas


def sync():
    if tmux("show", "-gqv", "@lateral").strip() != "1":
        return
    for w, j in paineis().items():
        if not j["reais"]:                      # só sobrou a barra: fecha a aba
            tmux("kill-window", "-t", w)
            continue
        if j["zoom"]:
            continue
        for extra in j["barras"][1:]:
            tmux("kill-pane", "-t", extra["id"])
        if not j["barras"]:
            p = tmux("split-window", "-dhbf", "-l", str(LARG), "-t", j["reais"][0]["id"], "-P", "-F", "#{pane_id}", "").strip()
            if not p:
                continue
            tmux("set", "-p", "-t", p, "@barra", "1")
            tmux("set", "-p", "-t", p, "window-style", "bg=#{@thm_mantle}")
            tmux("set", "-p", "-t", p, "window-active-style", "bg=#{@thm_mantle}")
        else:
            b = j["barras"][0]
            if b["x"] != LARG:
                tmux("resize-pane", "-t", b["id"], "-x", str(LARG))
            if b["ativo"]:                      # o foco nunca fica na barra
                tmux("select-pane", "-t", j["reais"][0]["id"])
    desenhar()


def desenhar():
    for w, j in paineis().items():
        if not j["barras"] or j["zoom"]:
            continue
        b, abas = j["barras"][0], abas_de(j["s"])
        tela = "\033[?25l" + rgb("@thm_mantle", True) + "\033[H\033[2J"
        for i, (idx, wid, sino, ativ) in enumerate(abas):
            if i >= b["h"] - 3:
                break
            cor = "@thm_overlay_1"
            if wid == w:
                cor = "@thm_mauve"
            elif sino == "1":
                cor = "@thm_red"
            elif ativ == "1":
                cor = "@thm_yellow"
            tela += f"\033[{i + 1};1H" + quadrado(idx, cor)
        verde, nome = rgb("@thm_mantle", True) + rgb("@thm_green"), j["nome"]
        tela += f"\033[{b['h'] - 1};1H{verde}"
        e, d, cima_e, cima_d, baixo_e, baixo_d = bordas()
        if len(nome) == 1 and nome.isdigit():   # ícone e número num bloco só
            tela += f"{cima_e}\uf8db{cima_d}\033[{b['h']};1H{baixo_e}{chr(0xF8C0 + int(nome))}{baixo_d}\033[0m"
        else:
            tela += f"{e}\uf8da{d}" + f"\033[{b['h']};1H" + quadrado(nome, "@thm_green")
        tmux("display-message", "-I", "-t", b["id"], entrada=tela)


def clique(y, sessao):
    abas = abas_de(sessao)
    h = next((j["barras"][0]["h"] for j in paineis().values() if j["s"] == sessao and j["barras"]), 0)
    if y < len(abas) and y < h - 3:
        tmux("select-window", "-t", abas[y][1])


def desligar():
    tmux("set", "-gu", "@lateral")
    for h in HOOKS:
        tmux("set-hook", "-gu", f"{h}[90]")
    for j in paineis().values():
        if j["reais"]:
            for b in j["barras"]:
                tmux("kill-pane", "-t", b["id"])
    for o in ("pane-border-style", "pane-active-border-style"):
        tmux("set", "-gu", o)
    tmux("set", "-g", "status", "on")
    tmux("source-file", os.path.expanduser("~/.config/tmux/visual.conf"))


def ligar():
    tmux("set", "-g", "@lateral", "1")
    tmux("set", "-g", "status", "off")
    for h in HOOKS:
        tmux("set-hook", "-g", f"{h}[90]", f"run-shell -b '{os.path.realpath(__file__)} sync'")
    sync()


ESTADO = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "tmux-barra")
CONF = os.path.expanduser("~/.config/tmux/lateral.conf")


def ligada():
    return tmux("show", "-gqv", "@lateral").strip() == "1"


def usar(barra):
    with open(ESTADO, "w") as f:
        f.write(barra)
    if barra == "topo" and ligada():
        subprocess.run([os.path.realpath(__file__), "desligar"])
    elif barra == "lateral" and not ligada():
        tmux("source-file", CONF)      # liga os binds e chama `ligar`


def alternar():
    usar("topo" if ligada() else "lateral")


def inicio():
    try:
        with open(ESTADO) as f:
            if f.read().strip() == "lateral":
                tmux("source-file", CONF)
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    # estes chamam o próprio script de novo: não podem segurar a trava
    if sys.argv[1:] in (["usar", "lateral"], ["usar", "topo"]):
        sys.exit(usar(sys.argv[2]))
    if sys.argv[1:] in (["alternar"], ["inicio"]):
        sys.exit({"alternar": alternar, "inicio": inicio}[sys.argv[1]]())
    servidor = os.environ.get("TMUX", "x").split(",")[0].replace("/", "_")
    with open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"tmux-lateral{servidor}.lock"), "w") as trava:
        fcntl.flock(trava, fcntl.LOCK_EX)
        cmd = sys.argv[1] if len(sys.argv) > 1 else ""
        if cmd == "sync": sync()
        elif cmd == "ligar": ligar()
        elif cmd == "desligar": desligar()
        elif cmd == "clique": clique(int(sys.argv[2]), sys.argv[3])
        else: sys.exit(__doc__)
