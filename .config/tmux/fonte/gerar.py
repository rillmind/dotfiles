#!/usr/bin/env python3
"""Gera TmuxCantos.ttf: as bordas esquerda (U+F8E0) e direita (U+F8E1) dos quadrados da barra do tmux.

Mesmas métricas da JetBrains Mono (célula 600x1320); cada borda ocupa meia célula, então borda +
1 dígito + borda dá um quase quadrado. Precisa do fonttools.  Uso: gerar.py <saida.ttf>
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

LARG, TOPO, BASE = 600, 1020, -300
RAIO = 230          # arredondamento (300 = meia célula inteira)
SOBRA = 25          # entra um pouco na célula do número para não aparecer emenda


def borda(espelhada):
    x = (lambda v: LARG - v) if espelhada else (lambda v: v)
    e, d = LARG / 2, LARG + SOBRA
    p = [((e + RAIO, BASE), None), ((e, BASE + RAIO), (e, BASE)), ((e, TOPO - RAIO), None),
         ((e + RAIO, TOPO), (e, TOPO)), ((d, TOPO), None), ((d, BASE), None)]
    pen = TTGlyphPen(None)
    pen.moveTo((x(p[0][0][0]), p[0][0][1]))
    for (px, py), ctrl in p[1:]:
        if ctrl:
            pen.qCurveTo((x(ctrl[0]), ctrl[1]), (x(px), py))
        else:
            pen.lineTo((x(px), py))
    pen.closePath()
    return pen.glyph()


fb = FontBuilder(1000, isTTF=True)
fb.setupGlyphOrder([".notdef", "esq", "dir"])
fb.setupCharacterMap({0xF8E0: "esq", 0xF8E1: "dir"})
g = {".notdef": TTGlyphPen(None).glyph(), "esq": borda(False), "dir": borda(True)}
fb.setupGlyf(g)
fb.setupHorizontalMetrics({n: (LARG, getattr(v, "xMin", 0) or 0) for n, v in g.items()})
fb.setupHorizontalHeader(ascent=TOPO, descent=BASE)
fb.setupNameTable({"familyName": "Tmux Cantos", "styleName": "Regular", "psName": "TmuxCantos-Regular"})
fb.setupOS2(sTypoAscender=TOPO, sTypoDescender=BASE, sTypoLineGap=0, usWinAscent=TOPO, usWinDescent=-BASE)
fb.setupPost(isFixedPitch=1)
fb.save(sys.argv[1])
