#!/usr/bin/env python3
"""Gera o StylusVinhoImport.json: os userstyles do Catppuccin (MIT) com a paleta do tema Vinho.

A biblioteca de cores vai embutida em cada estilo, sem atualização automática (ela traria as cores do
Catppuccin de volta): para pegar correções dos sites, rode de novo e reimporte no Stylus.

  gerar-stylus-vinho.py [import.json v1.less]     sem argumentos, baixa as versões atuais
"""
import json
import os
import random
import re
import sys
import urllib.request

EXPORT = "https://github.com/catppuccin/userstyles/releases/download/all-userstyles-export/import.json"
LIB = "https://userstyles.catppuccin.com/lib/std/v1.less"
FORA = {"Codeberg Catppuccin"}     # importa o CSS pronto do Catppuccin: as cores não mudariam

NOMES = ("rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender text subtext1 "
         "subtext0 overlay2 overlay1 overlay0 surface2 surface1 surface0 base mantle crust").split()
VINHO = {
    "mocha": ("d8bfba dc9aa6 dc7396 c4527a e0566f d96b7e d98968 d9a862 a3ad7a 8fb0a4 9fb5c0 93a3c0 93a3c0 c99ab8 e8d5cf "
              "d8bfba c9aaab b08d94 9c777f 8a646c 5f2c3c 4a1d2c 35151f 1c0b12 180910 15070d").split(),
    "latte": ("8a5a55 a0525f a93d60 8c2f4b b22945 a83a50 9c502c 855b16 58652a 2f6758 3d6377 435782 435782 7d436b 35151f "
              "4a1d2c 5f2c3c 75505a 805a63 8a646c c79fa2 dcc0bc ebd7d1 fbf3ef f3e5e0 ead8d2").split(),
}
CTP = ("f5e0dc f2cdcd f5c2e7 cba6f7 f38ba8 eba0ac fab387 f9e2af a6e3a1 94e2d5 89dceb 74c7ec 89b4fa b4befe cdd6f4 bac2de "
       "a6adc8 9399b2 7f849c 6c7086 585b70 45475a 313244 1e1e2e 181825 11111b").split()


# ── filtro CSS que leva um ícone preto à cor pedida (aproximação por busca, com semente fixa) ──
def aplicar(p, _lim=lambda v: max(0.0, min(1.0, v))):
    inv, sep, sat, hue, bri, con = p
    c = [_lim(inv)] * 3
    def mat(m):
        return [_lim(sum(m[i * 3 + k] * c[k] for k in range(3))) for i in range(3)]
    s = 1 - _lim(sep)
    c = mat([.393 + .607 * s, .769 - .769 * s, .189 - .189 * s, .349 - .349 * s, .686 + .314 * s, .168 - .168 * s,
             .272 - .272 * s, .534 - .534 * s, .131 + .869 * s])
    s = sat
    c = mat([.213 + .787 * s, .715 - .715 * s, .072 - .072 * s, .213 - .213 * s, .715 + .285 * s, .072 - .072 * s,
             .213 - .213 * s, .715 - .715 * s, .072 + .928 * s])
    from math import cos, sin, radians
    a, b = cos(radians(hue)), sin(radians(hue))
    c = mat([.213 + a * .787 - b * .213, .715 - a * .715 - b * .715, .072 - a * .072 + b * .928,
             .213 - a * .213 + b * .143, .715 + a * .285 + b * .140, .072 - a * .072 - b * .283,
             .213 - a * .213 - b * .787, .715 - a * .715 + b * .715, .072 + a * .928 + b * .072])
    c = [_lim(v * bri) for v in c]
    return [_lim((v - .5) * con + .5) for v in c]


def filtro(hexa):
    alvo = [int(hexa[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rnd = random.Random(hexa)
    erro = lambda p: sum(abs(a - b) for a, b in zip(aplicar(p), alvo))
    lim = [(0, 1), (0, 1), (0, 50), (0, 360), (0, 2), (0, 2)]
    melhor, me = None, 9
    for _ in range(6):
        p = [rnd.uniform(a, b) for a, b in lim]; p[2] = rnd.uniform(1, 15); e = erro(p); passo = .3
        for i in range(1500):
            q = [max(a, min(b, v + rnd.gauss(0, passo * (b - a) * (.15 if b == 50 else 1)))) for v, (a, b) in zip(p, lim)]
            f = erro(q)
            if f < e: p, e = q, f
            passo = max(.003, passo * .996)
        if e < me: melhor, me = p, e
        if me < .012: break
    i, s, t, h, b, c = melhor
    return (f"brightness(0) saturate(100%) invert({i:.1%}) sepia({s:.1%}) saturate({t:.1%}) hue-rotate({h:.1f}deg) "
            f"brightness({b:.1%}) contrast({c:.1%})")


def biblioteca(less):
    def bloco(nome, f):
        return f"@{nome}: {{\n" + "".join(
            f"  @{fl}: {{ " + " ".join(f"@{n}: {f(h)};" for n, h in zip(NOMES, hs)) + " };\n" for fl, hs in VINHO.items()) + "};\n"
    i = less.index("#lib {")
    return bloco("catppuccin", lambda h: "#" + h) + bloco("catppuccin-filters", filtro) + less[i:]


def baixar(url):
    return urllib.request.urlopen(url, timeout=60).read().decode()


def converter(x, lib):
    s, u = x["sourceCode"], x["usercssData"]
    nome = x["name"].replace("Catppuccin", "Vinho")
    ns = u["namespace"].replace("github.com/catppuccin/userstyles/styles/", "github.com/rillmind/vinho/stylus/")
    desc = f"{nome.removesuffix(' Vinho')} nas cores do tema Vinho (baseado no Catppuccin userstyles, MIT)"
    cab, corpo = s.split("==/UserStyle== */", 1)
    cab = re.sub(r"(?m)^@name .*", f"@name {nome}", cab)
    cab = re.sub(r"(?m)^@namespace .*", f"@namespace {ns}", cab)
    cab = re.sub(r"(?m)^@description .*", f"@description {desc}", cab)
    cab = re.sub(r"(?m)^@(updateURL|supportURL) .*\n", "", cab)
    cab = re.sub(r'(?m)^(@var select (?:light|dark)Flavor )"[^"]*" .*',
                 lambda m: m[1] + ('"Modo claro" ["latte:Vinho claro*", "mocha:Vinho escuro"]' if "light" in m[1]
                                   else '"Modo escuro" ["latte:Vinho claro", "mocha:Vinho escuro*"]'), cab)
    corpo = re.sub(r'(?m)^@import "https://userstyles\.catppuccin\.com/lib/(?:std/v1|lib)\.less";\n?', "", corpo)
    troca = dict(zip(CTP, VINHO["mocha"]))
    corpo = re.sub(r"#([0-9a-fA-F]{6})\b", lambda m: "#" + troca.get(m[1].lower(), m[1]), corpo)
    u = {k: v for k, v in u.items() if k not in ("updateURL", "supportURL")}
    u.update(name=nome, namespace=ns, description=desc)
    for k, rot, pad in (("lightFlavor", "Modo claro", "latte"), ("darkFlavor", "Modo escuro", "mocha")):
        if k in u.get("vars", {}):
            v = u["vars"][k] = json.loads(json.dumps(u["vars"][k]))
            v.update(label=rot, default=pad)
            v["options"] = [dict(o, label={"latte": "Vinho claro", "mocha": "Vinho escuro"}[o["name"]],
                                 **({"default": o["name"] == pad} if "default" in o else {}))
                            for o in v["options"] if o["name"] in ("latte", "mocha")]
    return {"enabled": x.get("enabled", True), "name": nome, "description": desc, "author": x.get("author", "Catppuccin"),
            "usercssData": u, "sourceCode": cab + "==/UserStyle== */" + corpo.rstrip("\n") + "\n\n" + lib}


def main():
    if len(sys.argv) == 3:
        dados, less = open(sys.argv[1]).read(), open(sys.argv[2]).read()
    else:
        dados, less = baixar(EXPORT), baixar(LIB)
    d = json.loads(dados)
    lib = biblioteca(less)
    saida = [d[0]] + [converter(x, lib) for x in d[1:] if x["name"] not in FORA]
    destino = os.path.join(os.path.dirname(os.path.realpath(__file__)), "StylusVinhoImport.json")
    with open(destino, "w") as f:
        json.dump(saida, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(saida) - 1} estilos em {destino}")


if __name__ == "__main__":
    main()
