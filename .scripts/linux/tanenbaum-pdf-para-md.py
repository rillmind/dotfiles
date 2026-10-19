#!/usr/bin/env python3
"""
tanenbaum-pdf-para-md.py — converte o PDF de "Sistemas Operacionais Modernos"
(Tanenbaum & Bos, 4ª ed., Pearson 2016, pt-BR) em um arquivo Markdown por capítulo.

POR QUE O PDF (E NÃO O EPUB)
    O EPUB que circula foi gerado do PDF com pdftohtml/calibre: as duas colunas
    saem intercaladas linha a linha e as figuras se perdem. O PDF é o original
    do InDesign, com texto nativo (sem OCR) e bookmarks, então é a fonte correta.

REQUISITOS
    python3 -m venv ~/venv-pdf && ~/venv-pdf/bin/pip install pymupdf

USO
    python -I tanenbaum-pdf-para-md.py LIVRO.pdf SAIDA/            # livro inteiro
    python -I tanenbaum-pdf-para-md.py LIVRO.pdf SAIDA/ 01,02      # só esses capítulos
    python -I tanenbaum-pdf-para-md.py --sumario SAIDA/            # só refaz o sumario.md

SAÍDA
    SAIDA/00-prefacio.md, 01-introducao.md, ..., 13-sugestoes-de-leitura-e-referencias.md
    SAIDA/img/capNN/fig-X-Y.png   recorte de cada figura (200 dpi)
    SAIDA/sumario.md              títulos e subtítulos de todos os capítulos,
                                  com links no formato do Obsidian ([[arquivo#Título]])

COMO O PDF É LIDO (mapa de fontes deste livro)
    TimesNewRoman 11pt ........ texto corrido
    TimesNewRoman 10pt ........ seção "Problemas"
    TimesNewRoman  9pt ........ notas de rodapé (vão para o fim do capítulo)
    Verdana-Bold + HelveticaLTStd-Cond(14/12pt) ... títulos de seção (##) e subseção (###)
    Helvetica-Bold "FIGURA X.Y" ... legenda (fica ACIMA do desenho)
    Helvetica 8pt ............. rótulos dentro das figuras (vão só na imagem)
    Helvetica 9-10.6pt ........ código: no meio da frase vira `código`; linha solta vira bloco ```
    Frutiger ................... cabeçalho da página (descartado)
    UniversLTStd > 60pt ....... letra capitular da abertura de capítulo
    O sumário de bookmarks do PDF (nível 1) dá o intervalo de páginas de cada capítulo.

O QUE A CONVERSÃO ALTERA (forma, nunca o texto)
    - remove cabeçalhos, rodapés e números de página; omite o Índice remissivo;
    - o texto de dentro de figuras/tabelas/listagens numeradas existe só no PNG;
    - notas de rodapé vão para uma seção "Notas" no fim do capítulo;
    - junta palavras hifenizadas na quebra de linha (ex.: "regis-/tradores");
      o hífen repetido do português ("código-/-fonte") é preservado como um só;
    - "PROBLEMAS" -> "Problemas", "FIGURA" -> "Figura", título "Capítulo N — Nome";
    - expoentes viram <sup>, o glifo privado U+E033 (fonte MathematicalPi) vira "×";
    - escapa * _ ` < [ ] com barra invertida; código solto perde a indentação.

ESPECÍFICO DESTE PDF (ajustar se for reaproveitar em outro livro)
    - margens das colunas: páginas de índice par 34/295 pt, ímpar 43/303 pt;
    - fim de figura = filete verde-azulado (RGB ~0.23, 0.67, 0.65), que também dá a largura dela;
    - nomes de fontes acima; faixa útil da página entre y=50 e y=748;
    - a bibliografia (seção "13.2 Referências") usa recuo deslocado.

LIMITAÇÕES CONHECIDAS
    - o box "Sala Virtual" do Prefácio cai no meio de uma palavra;
    - as fronteiras de parágrafo são inferidas (recuo de 1ª linha, espaço vertical),
      então em casos raros dois parágrafos podem sair juntos ou um sair partido.

VERIFICAÇÃO FEITA NA CONVERSÃO ORIGINAL (19/10/2026)
    509 títulos do sumário presentes, 402 figuras recortadas, 52.848 linhas de texto
    do PDF encontradas nos .md (0 ausentes).
"""
import os
import re
import sys
import unicodedata

import pymupdf

DPI = 200          # resolução dos recortes de figura
TOP, BOTTOM = 50, 748  # acima/abaixo disso é cabeçalho ou rodapé

# limpeza de caracteres: marcador de tab do InDesign, hífen suave, espaços especiais
CLEAN = str.maketrans({
    "\x07": "", "\xad": "", " ": " ", " ": " ", "\t": " ", " ": " ",
    "": "×",  # sinal de multiplicação na fonte MathematicalPi (uso privado)
})

MD_ESC = re.compile(r"([*_`<\[\]])")

# preenchidos em main()
doc = None
W = MID = 0.0


# ---------------------------------------------------------------- utilitários

def slug(s):
    """'Entrada/saída' -> 'entrada-saida' (nome de arquivo)."""
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def is_times(f):
    return f.startswith("Times")


def line_text(ln):
    return "".join(s["text"] for s in ln["spans"]).translate(CLEAN)


def main_span(ln):
    """Span com mais texto: define fonte/tamanho "da linha"."""
    return max(ln["spans"], key=lambda s: len(s["text"].strip()))


def union(rects):
    r = pymupdf.Rect(rects[0])
    for q in rects[1:]:
        r |= q
    return r


# ---------------------------------------------------------------- classificação de linhas

def classify(ln, pno, chapter_first):
    """Rotula uma linha do PDF: skip, dropcap, caption, heading, footnote, body ou other.

    'other' é texto que não é corpo (em geral rótulos de figura); page_figures()
    decide depois se pertence a uma figura ou se é código solto no texto.
    """
    x0, y0, x1, y1 = ln["bbox"]
    txt = line_text(ln).strip()
    ms = main_span(ln)
    f, sz = ms["font"], ms["size"]
    if not txt:
        return "skip"
    if y1 < TOP and f.startswith("Frutiger"):
        return "skip"  # cabeçalho
    if y0 > BOTTOM:
        return "skip"  # rodapé / marcas de impressão
    if f.startswith("UniversLTStd") and sz > 60 and len(txt) == 1:
        return "dropcap"
    # abertura de capítulo: "capítulo", número gigante e título decorativo
    if f.startswith("Verdana") and txt.lower() == "capítulo":
        return "skip"
    if f.startswith("UniversLTStd") and sz >= 40:
        return "skip"  # títulos decorativos (ex.: "SOBRE OS AUTORES"): fora do fluxo das colunas
    if chapter_first and f.startswith("Verdana") and sz > 20:
        return "skip"
    first = ln["spans"][0]
    if first["font"].startswith("Helvetica-Bold") and txt.startswith("FIGURA"):
        return "caption"
    if any(s["font"].startswith("Verdana-Bold") for s in ln["spans"]) or \
            (f.startswith("HelveticaLTStd") and sz >= 12):
        return "heading"
    if is_times(f) and sz < 9.5:
        return "footnote"
    if any(is_times(s["font"]) and s["size"] >= 9.5 and s["text"].strip() for s in ln["spans"]):
        return "body"
    return "other"


# ---------------------------------------------------------------- formatação inline

def span_style(s, base_size):
    """Estilo Markdown de um span: sup, code, b, i, bi ou ''."""
    f = s["font"]
    if s["size"] < base_size * 0.72 and s["text"].strip():
        return "sup"  # expoente / marca de nota
    if f.startswith(("Helvetica", "Arial", "Courier")) and "Bold" not in f:
        return "code"  # nomes de chamadas, comandos etc. no meio do texto
    b = "Bold" in f or s["flags"] & 16
    i = "Italic" in f or "Oblique" in f or "Ital" in f
    return "bi" if b and i else "b" if b else "i" if i else ""


def line_runs(ln):
    """Linha -> lista de [texto, estilo]."""
    base = max(s["size"] for s in ln["spans"])
    return [[s["text"].translate(CLEAN), span_style(s, base)] for s in ln["spans"]]


def render_runs(runs):
    """Junta runs de mesmo estilo e aplica a marcação Markdown.

    Os runs de um parágrafo inteiro são fundidos antes de marcar, para que um
    negrito quebrado em duas linhas vire um único **...** e não **a****b**.
    """
    merged = []
    for t, st in runs:
        if merged and (merged[-1][1] == st or not t.strip()):
            merged[-1][0] += t
        elif merged and not merged[-1][0].strip():
            merged[-1] = [merged[-1][0] + t, st]
        else:
            merged.append([t, st])
    out = []
    for t, st in merged:
        lead = t[: len(t) - len(t.lstrip())]
        trail = t[len(t.rstrip()):]
        core = t.strip()
        if not core:
            out.append(t)
            continue
        if st == "code":
            core = "`" + core.replace("`", "'") + "`"
        else:
            core = MD_ESC.sub(r"\\\1", core)
            if st == "b":
                core = f"**{core}**"
            elif st == "i":
                core = f"*{core}*"
            elif st == "bi":
                core = f"***{core}***"
            elif st == "sup":
                core = f"<sup>{core}</sup>"
        out.append(lead + core + trail)  # espaços ficam fora dos marcadores
    s = "".join(out)
    return re.sub(r"[ ]{2,}", " ", s).strip()


def append_line(runs, new):
    """Acrescenta uma linha ao parágrafo, desfazendo a hifenização de fim de linha.

    - "código-" + "-fonte"  -> "código-fonte" (o português repete o hífen na quebra)
    - "regis-" + "tradores" -> "registradores" (próxima começa minúscula)
    - "TA-" + "NENBAUM"     -> "TANENBAUM" (palavra toda em maiúsculas)
    - caso contrário, junta com um espaço.
    """
    if not runs:
        runs.extend(new)
        return
    while runs and not runs[-1][0].strip():
        runs.pop()
    if not runs:
        runs.extend(new)
        return
    last = runs[-1]
    last[0] = last[0].rstrip()
    first_txt = "".join(t for t, _ in new).lstrip()
    if last[0].endswith("-") and first_txt.startswith("-"):
        last[0] = last[0][:-1]
    elif last[0].endswith("-") and len(last[0]) > 1 and last[0][-2].isalpha() and \
            (first_txt[:1].islower() or (last[0][-2].isupper() and first_txt[:2].isupper())):
        last[0] = last[0][:-1]
    else:
        last[0] += " "
    new[0][0] = new[0][0].lstrip()
    runs.extend(new)


# ---------------------------------------------------------------- figuras

def mark_code(lines, cls, used):
    """Linhas 'other' em Helvetica 9-10.6 que não caíram em figura são código no texto."""
    for i, c in enumerate(cls):
        if c == "other" and i not in used:
            ms = main_span(lines[i])
            if ms["font"].startswith(("Helvetica", "Arial")) and "Bold" not in ms["font"] and 8.9 <= ms["size"] <= 10.7:
                cls[i] = "body"


def page_figures(page, lines, cls):
    """Localiza as figuras da página.

    Cada figura começa numa legenda "FIGURA X.Y" e o desenho fica logo ABAIXO dela.
    Os candidatos (rótulos 'other', vetores e imagens raster) são atribuídos à
    legenda mais próxima acima, respeitando:
      - o limite inferior: o filete verde de fim de figura ou a próxima linha
        de texto corrido/título/legenda sob a legenda;
      - o limite lateral: a largura desse filete (meia coluna ou página toda);
      - a coluna: legenda estreita prefere itens da mesma coluna. Só aceita
        itens da outra coluna se não houver texto corrido no caminho.
    Também marca as continuações da legenda (cls 'capcont') e o código solto.

    Devolve [(idx_legenda, [idx_continuações], rect_legenda, rect_figura|None)].
    """
    caps = [i for i, c in enumerate(cls) if c == "caption"]
    # continuação da legenda: Helvetica-Light logo abaixo, recuada após "FIGURA X.Y"
    cap_cont = {}
    for i in caps:
        cx0, cy0, cx1, cy1 = lines[i]["bbox"]
        conts, last_y = [], cy1
        for j, ln in enumerate(lines):
            if cls[j] != "other" or j in conts:
                continue
            x0, y0, x1, y1 = ln["bbox"]
            if main_span(ln)["font"].startswith("Helvetica-Light") and 0 <= y0 - last_y + 4 < 8 and cx0 + 10 <= x0 < cx0 + 70:
                conts.append(j)
                last_y = y1
        for j in conts:
            cls[j] = "capcont"
        cap_cont[i] = conts
    if not caps:
        mark_code(lines, cls, set())
        return []

    # candidatos a conteúdo de figura
    head_lines = [pymupdf.Rect(lines[i]["bbox"]) for i, c in enumerate(cls) if c == "heading"]
    items = [(pymupdf.Rect(lines[i]["bbox"]), i) for i, c in enumerate(cls) if c == "other"]
    for d in page.get_drawings():
        r = d["rect"]
        if r.y1 < 52 or r.y0 > BOTTOM or r.x0 < 5 or r.x1 > W - 5 or r.width > W - 20:
            continue  # cabeçalho, marcas de corte, fundo da página
        if r.height < 2 and r.width > 300 and any(0 <= r.y0 - h.y1 < 25 for h in head_lines):
            continue  # filete abaixo de título
        if r.is_empty and r.width == 0 and r.height == 0:
            continue
        c = d.get("fill") or d.get("color")
        if r.height < 3 and r.width > 200 and c and c[0] < 0.4 and c[1] > 0.5:
            continue  # filete verde de fim de figura (não entra no recorte)
        items.append((r, None))
    for info in page.get_image_info():
        r = pymupdf.Rect(info["bbox"]) & page.rect
        if r.width > 5 and r.height > 5 and r.width < W - 20 and r.y0 > 52:
            items.append((r, None))  # imagens raster (fotos, telas)

    figs = {i: [] for i in caps}
    body_rects = [pymupdf.Rect(lines[j]["bbox"]) for j, c in enumerate(cls) if c == "body"]
    used = set()
    cap_rects = {i: union([pymupdf.Rect(lines[j]["bbox"]) for j in [i] + cap_cont[i]]) for i in caps}

    # limites de cada figura
    teal = lambda c: c is not None and c[0] < 0.4 and c[1] > 0.5 and c[2] > 0.5
    hrules = [d["rect"] for d in page.get_drawings()
              if d["rect"].height < 3 and d["rect"].width > 200 and 52 < d["rect"].y0 < BOTTOM
              and (teal(d.get("fill")) or teal(d.get("color")))]
    stops, xlims = {}, {}
    for i in caps:
        cr = cap_rects[i]
        st = BOTTOM
        xlims[i] = (0, W)
        for q in hrules:
            if q.y0 > cr.y1 + 2 and q.y0 < st and q.x0 < (cr.x0 + cr.x1) / 2 < q.x1:
                st = q.y0
                xlims[i] = (q.x0 - 6, q.x1 + 6)  # o filete final dá a largura da figura
        xa, xb = cr.x0 - 10, cr.x0 + max(cr.width, 240)
        for j, c in enumerate(cls):
            if c in ("body", "heading", "caption") and j != i:
                x0, y0, x1, y1 = lines[j]["bbox"]
                if y0 > cr.y1 and xa <= (x0 + x1) / 2 <= xb:
                    st = min(st, y0)
        stops[i] = st

    # atribuição: primeiro só legendas da mesma coluna, depois qualquer uma
    for r, li in items:
        cy = (r.y0 + r.y1) / 2
        cx = (r.x0 + r.x1) / 2
        best = None
        for same_side in (True, False):
            bd = 1e9
            for i in caps:
                cr = cap_rects[i]
                if same_side and cr.width < 280 and ((cr.x0 + cr.x1) / 2 < MID) != (cx < MID):
                    continue
                if not xlims[i][0] <= cx <= xlims[i][1]:
                    continue
                if not same_side and any(((b.x0 + b.x1) / 2 < MID) == (cx < MID) and cr.y1 < b.y0 < r.y0
                                         for b in body_rects):
                    continue  # há texto corrido entre a legenda e o item, na coluna do item
                d = r.y0 - cr.y1
                if d >= -6 and cy < stops[i] and d < bd:
                    best, bd = i, d
            if best is not None:
                break
        if best is None:
            continue  # fora de qualquer figura: decoração
        figs[best].append(r)
        if li is not None:
            used.add(li)
    mark_code(lines, cls, used)
    return [(i, cap_cont[i], cap_rects[i], union(figs[i]) if figs[i] else None) for i in caps]


# ---------------------------------------------------------------- montagem do Markdown

class Ctx:
    """Estado de um capítulo durante a conversão."""

    def __init__(self, num, imgdir, imgrel):
        self.num = num
        self.imgdir = imgdir          # onde salvar os PNG
        self.imgrel = imgrel          # caminho relativo usado nos links
        self.md = []                  # blocos já prontos
        self.para = None              # parágrafo em construção: {kind, runs, indent[, lines]}
        self.pending_figs = []        # figuras esperando o parágrafo atual terminar
        self.footnotes = []           # [[número, texto], ...]
        self.dropcap = ""             # capitular a prefixar na próxima linha
        self.dropcap_rect = None
        self.dropcap_page = None
        self.fig_names = set()
        self.hanging = False          # bibliografia com recuo deslocado
        self.prev_line = None         # (página, coluna, rect) da última linha de corpo

    def flush(self):
        """Fecha o parágrafo atual e despeja as figuras que estavam esperando."""
        if self.para and self.para["runs"]:
            txt = render_runs(self.para["runs"])
            k = self.para["kind"]
            if k == "item":
                txt = "- " + re.sub(r"^•\s*", "", txt)
            elif k == "prob":
                m = re.match(r"^(\d+)\.\s*(.*)", txt, re.S)
                txt = f"{m.group(1)}. {m.group(2)}" if m else txt
            elif k == "sub":
                txt = "    - " + txt
            elif k == "code":
                txt = "```\n" + "\n".join("".join(t for t, _ in ln) for ln in self.para["lines"]) + "\n```"
            if txt.strip():
                self.md.append(txt)
        self.para = None
        self.md.extend(self.pending_figs)
        self.pending_figs = []

    def add_fig(self, text):
        # figura no meio de um parágrafo entra depois dele, para não partir a frase
        if self.para:
            self.pending_figs.append(text)
        else:
            self.md.append(text)


def process_page(ctx, pno, chapter_first):
    """Classifica as linhas da página, acha as figuras e emite tudo em ordem de leitura.

    Ordem de leitura: elementos de largura total (figuras largas, títulos com
    filete) cortam a página em faixas horizontais. Dentro de cada faixa vem a
    coluna esquerda inteira e depois a direita.
    """
    page = doc[pno]
    lines = [ln for b in page.get_text("dict")["blocks"] if b["type"] == 0 for ln in b["lines"] if ln["spans"]]
    cls = [classify(ln, pno, chapter_first) for ln in lines]
    figs = page_figures(page, lines, cls)

    # elementos: (tipo, rect, payload)
    elems = []
    fig_rects = []
    for ci, conts, cr, rect in figs:
        fig_rects.append(rect)
        cap = " ".join(line_text(lines[j]) for j in [ci] + conts)
        elems.append(("fig", cr | rect if rect else cr, (ci, conts, cr, rect, cap)))
    in_fig = lambda r: any(fr is not None and fr.contains(pymupdf.Point((r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2)) for fr in fig_rects)
    for ln, c in zip(lines, cls):
        r = pymupdf.Rect(ln["bbox"])
        if c in ("skip", "caption", "capcont", "other"):
            continue
        if c in ("body", "footnote") and in_fig(r):
            continue  # texto dentro da figura (vai na imagem)
        elems.append((c, r, ln))

    # títulos com filete largo logo abaixo ocupam a largura toda
    rules = [d["rect"] for d in page.get_drawings() if d["rect"].height < 2 and d["rect"].width > 400 and 52 < d["rect"].y0 < BOTTOM]

    def is_full(e):
        k, r, _ = e
        if k == "fig":
            return r.width > 300 or (r.x0 < MID - 20 and r.x1 > MID + 20)
        if k == "heading":
            return any(-4 <= q.y0 - r.y1 < 25 for q in rules)
        return False

    # junta títulos que quebraram em duas linhas
    merged = []
    for e in sorted(elems, key=lambda e: (e[1].x0 >= MID - 5, e[1].y0)):
        if e[0] == "heading" and merged and merged[-1][0] == "heading" and -8 <= e[1].y0 - merged[-1][1].y1 < 8:
            k, r, lns = merged[-1]
            merged[-1] = ("heading", r | e[1], lns + [e[2]])
        elif e[0] == "heading":
            merged.append(("heading", e[1], [e[2]]))
        else:
            merged.append(e)
    elems = merged

    # faixas: tudo cujo centro está entre dois elementos largos; nada é descartado
    fulls = sorted([e for e in elems if is_full(e)], key=lambda e: e[1].y0)
    rest = [e for e in elems if not is_full(e)]
    order = []
    prev_y = -1
    for fe in fulls + [None]:
        lim = fe[1].y0 if fe else 1e9
        band = [e for e in rest if prev_y <= (e[1].y0 + e[1].y1) / 2 < lim]
        # notas: o número (sobrescrito) fica um pouco abaixo do topo do texto, por isso y1
        band.sort(key=lambda e: ((e[1].x0 + e[1].x1) / 2 >= MID, e[1].y1 if e[0] == "footnote" else e[1].y0))
        order.extend(band)
        if fe:
            order.append(fe)
            prev_y = fe[1].y0

    # margem esquerda de cada coluna (para medir recuo): fixa pela paridade da página
    colx = {False: 34, True: 295} if pno % 2 == 0 else {False: 43, True: 303}
    for k, r, p in order:
        emit(ctx, k, r, p, page, colx)


def emit(ctx, k, r, p, page, colx):
    """Transforma um elemento da página em Markdown (ou acumula no parágrafo atual)."""
    if k == "skip":
        return

    if k == "dropcap":
        ctx.dropcap = line_text(p).lstrip()  # "A " / "O " mantêm o espaço: são palavras
        ctx.dropcap_rect = r
        ctx.dropcap_page = page.number
        return

    if k == "heading":
        txt = re.sub(r"\s+", " ", " ".join(line_text(ln) for ln in p)).strip()
        size = max(s["size"] for ln in p for s in ln["spans"])
        ctx.flush()
        if txt.upper() == "PROBLEMAS":
            txt = "Problemas"
        ctx.md.append(f"{'##' if size >= 13.5 else '###'} {txt}")
        ctx.hanging = txt.startswith("13.2 Refer")
        return

    if k == "footnote":
        # o número da nota pode vir numa "linha" separada do texto
        t = line_text(p).strip()
        m = re.match(r"^(\d+)\s+(.*)", t)
        sp0 = p["spans"][0]
        if re.fullmatch(r"\d+", t) and sp0["size"] < 7:
            ctx.footnotes.append([t, ""])
        elif ctx.footnotes and ctx.footnotes[-1][1] == "":
            ctx.footnotes[-1][1] = t
        elif m and sp0["size"] < 7:
            ctx.footnotes.append([m.group(1), m.group(2)])
        elif ctx.footnotes:  # continuação da nota anterior
            prev = ctx.footnotes[-1]
            if prev[1].endswith("-") and t[:1].islower():
                prev[1] = prev[1][:-1] + t
            else:
                prev[1] += " " + t
        else:
            ctx.footnotes.append(["", t])
        return

    if k == "fig":
        ci, conts, cr, rect, cap = p
        cap = re.sub(r"\s+", " ", cap).strip()
        cap = re.sub(r"(\w)- (\w)", r"\1\2", cap)
        m = re.match(r"FIGURA\s+(\d+)\.(\d+)\s*(.*)", cap)
        if m:
            name, label, rest = f"fig-{m.group(1)}-{m.group(2)}", f"Figura {m.group(1)}.{m.group(2)}", m.group(3)
        else:
            name, label, rest = f"fig-p{page.number + 1}", "Figura", cap
        base, n = name, 2
        while name in ctx.fig_names:
            name = f"{base}-{n}"
            n += 1
        ctx.fig_names.add(name)
        out = [f"**{label}** — {MD_ESC.sub(r'\\\1', rest)}"]
        if rect is not None and rect.width > 3 and rect.height > 3:
            clip = (rect + (-4, -4, 4, 4)) & page.rect
            os.makedirs(ctx.imgdir, exist_ok=True)
            page.get_pixmap(clip=clip, dpi=DPI).save(os.path.join(ctx.imgdir, name + ".png"))
            out.insert(0, f"![{label}]({ctx.imgrel}/{name}.png)")
        ctx.add_fig("\n\n".join(out))
        return

    # ---- linha de corpo: decide se continua o parágrafo atual ou abre outro
    ln = p
    raw = line_text(ln)
    txt = raw.strip()
    col = (r.x0 + r.x1) / 2 >= MID
    indent = r.x0 - colx[col]
    dc = ctx.dropcap_rect
    if dc is not None and page.number == ctx.dropcap_page and r.y0 < dc.y1 + 2 and r.x0 >= dc.x0 + 10:
        indent = 0  # linhas recuadas ao lado da capitular não são parágrafo novo
    size = main_span(ln)["size"]
    runs = line_runs(ln)
    if ctx.dropcap:
        runs[0][0] = ctx.dropcap + runs[0][0].lstrip()
        ctx.dropcap = ""
    is_code = all(st == "code" or not t.strip() for t, st in runs)
    prob_start = re.match(r"^\s*\d+\.\s", raw) and size < 10.5   # "12. Pergunta..." (Problemas)
    sub_start = re.match(r"^\(\w\)\s", txt) and size < 10.5      # "(a) item" dentro de um problema
    bullet = txt.startswith("•")
    cur = ctx.para
    gap = None  # espaço vertical em relação à linha anterior da mesma coluna
    prev = ctx.prev_line
    if prev and prev[0] == page.number and prev[1] == col and 0 < r.y0 - prev[2].y0 < 40:
        gap = r.y0 - prev[2].y1
    ctx.prev_line = (page.number, col, r)

    if is_code:
        if cur and cur["kind"] == "code":
            cur["lines"].append(runs)
        else:
            ctx.flush()
            ctx.para = {"kind": "code", "runs": runs, "lines": [runs]}
        return

    new = None
    if bullet:
        new = "item"
    elif prob_start:
        new = "prob"
    elif sub_start:
        new = "sub"
    elif cur is None or cur["kind"] == "code":
        new = "para"
    elif ctx.hanging:
        new = "para" if indent < 4 else None  # bibliografia: entrada nova começa na margem
    elif size >= 10.5 and 8 < indent < 22 and cur["kind"] in ("para", "item"):
        # recuo de 1ª linha (14pt) => parágrafo novo; continuação de item tem o recuo do item
        if not (cur["kind"] == "item" and abs(indent - cur.get("indent", 0)) < 3):
            new = "para"
    elif cur["kind"] in ("prob", "sub") and size >= 10.5:
        new = "para"
    elif size >= 10.5 and gap is not None and gap > 0.5 and cur["kind"] in ("para", "item"):
        new = "para"  # espaço vertical extra separa entradas (ex.: leituras sugeridas)
    if new:
        ctx.flush()
        ctx.para = {"kind": new, "runs": [], "indent": indent}
        if new == "prob":
            runs[0][0] = runs[0][0].lstrip()
    append_line(ctx.para["runs"], runs)


# ---------------------------------------------------------------- sumário

def write_summary(out):
    """Gera OUT/sumario.md a partir dos títulos #, ## e ### dos capítulos gerados.

    Usa links do Obsidian: [[arquivo#Título|Título]]. Títulos com # | [ ] ^
    quebrariam o link, então esses saem como texto simples.
    """
    files = sorted(f for f in os.listdir(out) if re.match(r"^\d\d-.*\.md$", f))
    res = ["# Sumário — Sistemas Operacionais Modernos (Tanenbaum & Bos, 4ª ed.)"]
    bad = re.compile(r"[#|\[\]^]")
    link = lambda stem, h: h if bad.search(h) else f"[[{stem}#{h}|{h}]]"
    nlinks = 0
    for f in files:
        stem = f[:-3]
        with open(os.path.join(out, f), encoding="utf-8") as fh:
            heads = re.findall(r"^(#{1,3}) (.+?)\s*$", fh.read(), re.M)
        for hashes, h in heads:
            if len(hashes) == 1:
                res.append(f"\n## [[{stem}|{h}]]\n")
            elif len(hashes) == 2:
                res.append(f"- {link(stem, h)}")
                nlinks += 1
            else:
                res.append(f"    - {link(stem, h)}")
                nlinks += 1
    with open(os.path.join(out, "sumario.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(res) + "\n")
    print("sumario.md", nlinks, "títulos")


# ---------------------------------------------------------------- principal

def main():
    global doc, W, MID
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--sumario":
        write_summary(args[1])
        return
    if len(args) not in (2, 3):
        sys.exit(__doc__)
    pdf, out = args[0], args[1]
    only = set(args[2].split(",")) if len(args) == 3 else None

    doc = pymupdf.open(pdf)
    W = doc[0].rect.width
    MID = W / 2

    # capítulos = bookmarks de nível 1; cada um vai até a página antes do próximo
    top = [(t, p) for l, t, p in doc.get_toc() if l == 1]
    os.makedirs(out, exist_ok=True)
    for idx, (title, start) in enumerate(top):
        end = top[idx + 1][1] - 1 if idx + 1 < len(top) else doc.page_count
        if title.startswith("Índice"):
            continue  # índice remissivo aponta para páginas impressas: inútil em .md
        m = re.match(r"^(\d+)\s+(.*)", title)
        num = int(m.group(1)) if m else (0 if idx == 0 else 99)
        key = f"{num:02d}"
        if only and key not in only:
            continue
        fname = f"{key}-{slug(m.group(2) if m else title)}.md"
        imgrel = f"img/cap{key}"
        ctx = Ctx(num, os.path.join(out, imgrel), imgrel)
        ctx.md.append(f"# Capítulo {num} — {m.group(2)}" if m else f"# {title}")
        for pno in range(start - 1, end):
            process_page(ctx, pno, pno == start - 1)
        ctx.flush()
        if ctx.footnotes:
            ctx.md.append("---\n\n**Notas**")
            for n_, t in ctx.footnotes:
                ctx.md.append(f"<sup>{n_}</sup> {t}" if n_ else t)
        with open(os.path.join(out, fname), "w", encoding="utf-8") as fh:
            fh.write("\n\n".join(x for x in ctx.md if x) + "\n")
        print(fname, end - start + 1, "págs", len(ctx.fig_names), "figs")
    write_summary(out)


if __name__ == "__main__":
    main()
