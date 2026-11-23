#!/usr/bin/env python3
"""Gera TmuxLateral.ttf: quadrados numerados da barra lateral, mais baixos que a linha para sobrar um
vão entre eles. U+F8D0-F8D9: miolo com o algarismo vazado; U+F8E2/F8E3: bordas. U+F8C0-F8C9, F8DA-F8DB e
F8E4-F8E7: ícone e número do servidor. U+F8E8-F8ED: bordas de cantos retos.

Precisa do fonttools.  Uso: gerar-lateral.py <JetBrainsMono-Bold.ttf> <saida.ttf>
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

LARG, TOPO, BASE = 617, 1020, -300      # 617 = a célula de 14 px na fonte 17 (o Ghostty arredonda 13,6 para cima)
VAO = 132                     # folga em cima e embaixo (1320 = 30 px; 132 = 3 px)
RAIO = 230
DESL = 44                     # bloco 1 px para a esquerda (617 = 14 px): compensa a folga de 2 px do Ghostty
T, B = TOPO - VAO, BASE + VAO
SUP, INF = TOPO + 14, BASE - 14   # peças emendadas passam um tico do limite, para não aparecer o risco


def borda(esq, topo=T, base=B, reto=False):
    """topo/base no limite da célula (SUP/INF) = canto reto, para emendar com a linha vizinha."""
    x = (lambda v: v) if esq else (lambda v: LARG - v)
    e, d = LARG / 2 + (-DESL if esq else DESL), LARG
    pen = TTGlyphPen(None)
    pen.moveTo((x(d), base))
    if reto or base == INF:
        pen.lineTo((x(e), base))
    else:
        pen.lineTo((x(e + RAIO), base))
        pen.qCurveTo((x(e), base), (x(e), base + RAIO))
    if reto or topo == SUP:
        pen.lineTo((x(e), topo))
    else:
        pen.lineTo((x(e), topo - RAIO))
        pen.qCurveTo((x(e), topo), (x(e + RAIO), topo))
    pen.lineTo((x(d), topo))
    pen.closePath()
    return pen.glyph()


src = TTFont(sys.argv[1])
gs, cmap, k = src.getGlyphSet(), src.getBestCmap(), 1000 / src["head"].unitsPerEm


def poli(pen, *pts):
    pen.moveTo(pts[0])
    for p in pts[1:]:
        pen.lineTo(p)
    pen.closePath()


def miolo(n, topo=T, base=B):
    pen = TTGlyphPen(None)
    # retângulo anti-horário; o desenho (horário) vira furo
    poli(pen, (0, base), (LARG, base), (LARG, topo), (0, topo))
    if n == "icone":            # >_ centrado na célula e no bloco
        m = (T + B) / 2
        e = 88                  # espessura do traço
        # centro deslocado junto com o bloco; um pouco mais estreito para o furo não sair da célula
        furo = TransformPen(pen, (513 / 577, 0, 0, 1, LARG / 2 - DESL - LARG / 2 * 513 / 577, 0))
        poli(furo, (20, m + 250 - e), (20 + e * .7, m + 250), (310, m + 20), (310, m - 20),
             (20 + e * .7, m - 250), (20, m - 250 + e), (190, m))
        poli(furo, (320, m - 250 + e), (LARG - 20, m - 250 + e), (LARG - 20, m - 250), (320, m - 250))
        return pen.glyph()
    g = cmap[ord(str(n))]
    dx = (LARG - gs[g].width * k) / 2 - DESL
    gs[g].draw(TransformPen(Cu2QuPen(pen, 1), (k, 0, 0, k, dx, 0)))
    return pen.glyph()


g = {".notdef": TTGlyphPen(None).glyph(), "esq": borda(True), "dir": borda(False)}
g.update({f"n{n}": miolo(n) for n in range(10)})
# servidor: bloco de duas linhas emendadas (ícone em cima, número embaixo)
g.update({"icone": miolo("icone"), "icone2": miolo("icone", base=INF),
          "esq_c": borda(True, base=INF), "dir_c": borda(False, base=INF),
          "esq_b": borda(True, topo=SUP), "dir_b": borda(False, topo=SUP)})
g.update({f"b{n}": miolo(n, topo=SUP) for n in range(10)})
# as mesmas bordas com cantos retos (tema Vinho)
for nome, args in (("", {}), ("_c", {"base": INF}), ("_b", {"topo": SUP})):
    g[f"esq{nome}_r"] = borda(True, reto=True, **args)
    g[f"dir{nome}_r"] = borda(False, reto=True, **args)
g["vazio"] = TTGlyphPen(None).glyph()
fb = FontBuilder(1000, isTTF=True)
fb.setupGlyphOrder(list(g))
# o ASCII vazio e as alturas x/maiúscula (iguais às da JetBrains Mono) evitam que o Ghostty a reescale
fb.setupCharacterMap({**{c: "vazio" for c in range(32, 127)}, 0xF8E2: "esq", 0xF8E3: "dir", 0xF8DA: "icone", 0xF8DB: "icone2",
                      0xF8E4: "esq_c", 0xF8E5: "dir_c", 0xF8E6: "esq_b", 0xF8E7: "dir_b",
                      0xF8E8: "esq_r", 0xF8E9: "dir_r", 0xF8EA: "esq_c_r", 0xF8EB: "dir_c_r",
                      0xF8EC: "esq_b_r", 0xF8ED: "dir_b_r",
                      **{0xF8C0 + n: f"b{n}" for n in range(10)}, **{0xF8D0 + n: f"n{n}" for n in range(10)}})
fb.setupGlyf(g)
fb.setupHorizontalMetrics({n: (600, getattr(v, "xMin", 0) or 0) for n, v in g.items()})
fb.setupHorizontalHeader(ascent=TOPO, descent=BASE)
fb.setupNameTable({"familyName": "Tmux Lateral", "styleName": "Regular", "psName": "TmuxLateral-Regular"})
fb.setupOS2(sTypoAscender=TOPO, sTypoDescender=BASE, sTypoLineGap=0, usWinAscent=TOPO, usWinDescent=-BASE,
            version=4, sxHeight=src["OS/2"].sxHeight, sCapHeight=src["OS/2"].sCapHeight)
fb.setupPost(isFixedPitch=1)
fb.save(sys.argv[2])
