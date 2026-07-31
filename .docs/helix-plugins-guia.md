# Guia de Plugins para Helix Editor

> **Nota:** O sistema de plugins do Helix (baseado em **Steel Scheme**) ainda não foi mesclado ao branch principal. Para usá-lo, é necessário compilar o fork do [mattwparas/helix](https://github.com/mattwparas/helix) no branch `steel-event-system`.

---

## 1. Compilando o Helix com suporte a plugins (Steel)

### Pré-requisitos

- Rust toolchain (rustc + cargo)
- Git
- Compilador C++14 (GCC, Clang, etc.)

### Passos

```bash
# Clone o fork com suporte a Steel
git clone https://github.com/mattwparas/helix.git
cd helix
git checkout steel-event-system

# Compila e instala:
#   hx                      - editor com suporte a plugins
#   steel                   - REPL da linguagem Steel
#   forge                   - gerenciador de pacotes (plugins)
#   steel-language-server   - LSP para Scheme/Steel
cargo xtask steel
```

Isso instala os binários em `~/.cargo/bin/` e a stdlib do Steel em `~/.steel/`.

### Configurar PATH

Adicione ao seu `~/.bashrc`, `~/.zshrc` ou equivalente:

```bash
export PATH="$PATH:$HOME/.cargo/bin:$HOME/.steel/bin"
```

### Verificar instalação

```bash
hx --version
forge --version
steel --version
```

---

## 2. Configuração inicial dos plugins

Crie os arquivos de configuração do Steel:

```bash
mkdir -p ~/.config/helix
touch ~/.config/helix/{init.scm,helix.scm}
```

### `helix.scm`

Este módulo é carregado pelo editor em tempo de execução. Funções exportadas aqui ficam disponíveis como comandos no Helix.

```scheme
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(provide git-add open-helix-scm open-init-scm)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

(define (shell . args)
  (helix.run-shell-command
    (string-join
      (map (lambda (x) (if (equal? x "%") (current-path) x)) args)
      " ")))

(define (git-add)
  (shell "git" "add" "%"))

(define (open-helix-scm)
  (helix.open (helix.static.get-helix-scm-path)))

(define (open-init-scm)
  (helix.open (helix.static.get-init-scm-path)))
```

### `init.scm`

Carregado após `helix.scm`. Usado para configuração do editor e inicialização de plugins.

```scheme
;; Configurar LSP para Scheme/Steel
(require "helix/configuration.scm")
(define-lsp "steel-language-server"
  (command "steel-language-server") (args '()))
(define-language "scheme"
  (language-servers '("steel-language-server")))
```

---

## 3. Instalando plugins com o `forge`

O `forge` é o gerenciador de pacotes do Steel/Helix.

```bash
# Instalar um plugin via git
forge pkg install --git <url-do-repositorio>
```

Os plugins são instalados em `~/.steel/pkg/` e devem ser carregados no `helix.scm` ou `init.scm`.

---

## 4. vim.hx — Bindings do Vim para Helix

Repositório: [mattwparas/vim.hx](https://github.com/mattwparas/vim.hx)

Este plugin adiciona emulação de teclas no estilo Vim (movimentos `w`, `b`, `gg`, `G`, etc.) dentro do Helix.

### Instalação

```bash
forge pkg install --git https://github.com/mattwparas/vim.hx.git
```

### Ativação

Adicione ao seu `~/.config/helix/init.scm`:

```scheme
(require "vim-hx/init.scm")
(set-vim-keybindings!)
```

### O que inclui

- Movimentos normais do Vim: `w`, `b`, `e`, `gg`, `G`, `0`, `$`, `^`
- Mudanças (`c`), deleção (`d`), yank (`y`) combinados com movimentos
- Modo visual (`v`, `V`)
- Suporte a seleção por objeto de texto (`va(`, `vi"`, etc.)

> **Alternativa:** [badranX/vim.hx](https://github.com/badranX/vim.hx) é outra implementação de emulação Vim que também funciona com o fork Steel.

---

## 5. Plugins recomendados

| Plugin | Descrição | Instalação |
|--------|-----------|------------|
| **oil.hx** | Gerenciador de arquivos estilo oil.nvim (editar filesystem como buffer) | `forge pkg install --git https://github.com/Ra77a3l3-jar/oil.hx.git` |
| **streal.hx** | Favoritar arquivos e alternar entre eles com números | `forge pkg install --git https://github.com/gllms/streal.hx.git` |
| **steel-pty** | Terminal embutido no Helix | `forge pkg install --git https://github.com/mattwparas/steel-pty` |
| **paredit.hx** | Edição estrutural para linguagens Lisp (barf/slurp, splice) | `forge pkg install --git https://github.com/waddie/paredit.hx.git` |
| **nrepl.hx** | Cliente nREPL para desenvolvimento Scheme interativo | `forge pkg install --git https://github.com/waddie/nrepl.hx.git` |
| **wakatime.hx** | Integração com WakaTime para métricas de codificação | `forge pkg install --git https://github.com/Xerxes-2/wakatime.hx.git` |
| **hxwiki** | Wiki pessoal estilo VimWiki com [[links]] e diário | `forge pkg install --git https://github.com/sipmann/hxwiki.git` |
| **notify.hx** | Sistema de notificações popup para plugins | `forge pkg install --git https://github.com/chuwy/notify.hx.git` |
| **helix-config** | Coleção de plugins do Matt (file tree, splash, file watcher) | `forge pkg install --git https://github.com/mattwparas/helix-config.git` |

### Exemplo de `init.scm` com vários plugins

```scheme
(require "helix/configuration.scm")
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/ext.scm")

;; vim bindings
(require "vim-hx/init.scm")
(set-vim-keybindings!)

;; terminal embutido
(require "steel-pty/term.scm")

;; paredit para Scheme
(require "paredit/init.scm")

;; streal - favoritos
(require "streal/streal.scm")

;; oil - file manager
(require "oil/oil.scm")
(oil-configure! #false #false)

;; LSP para Scheme
(define-lsp "steel-language-server"
  (command "steel-language-server") (args '()))
(define-language "scheme"
  (language-servers '("steel-language-server")))
```

---

## 6. Escrevendo seu próprio plugin

Crie um arquivo `.scm` em `~/.config/helix/cogs/` (ou qualquer subdiretório).

Exemplo — `cogs/git-blame.scm`:

```scheme
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text)

(provide git-blame)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

(define (selection-line-start)
  (let* ([focus (editor-focus)]
         [doc-id (editor->doc-id focus)]
         [text (editor->text doc-id)]
         [sel (helix.static.current-selection-object)]
         [range (helix.static.selection->primary-range sel)])
    (+ 1 (rope-char->line text (helix.static.range->from range)))))

(define (selection-line-end)
  (let* ([focus (editor-focus)]
         [doc-id (editor->doc-id focus)]
         [text (editor->text doc-id)]
         [sel (helix.static.current-selection-object)]
         [range (helix.static.selection->primary-range sel)])
    (rope-char->line text (helix.static.range->to range))))

(define (git-blame)
  (helix.run-shell-command
    (string-append
      "git blame -L"
      (int->string (selection-line-start))
      ","
      (int->string (selection-line-end))
      " " (current-path))))
```

Depois importe no `helix.scm`:

```scheme
(require "cogs/git-blame.scm")
(provide ... git-blame ...)
```

O comando `:git-blame` ficará disponível na paleta de comandos.

---

## 7. Links úteis

- [STEEL.md — Documentação oficial do fork](https://github.com/mattwparas/helix/blob/steel-event-system/STEEL.md)
- [steel-docs.md — API completa de funções Steel para Helix](https://github.com/mattwparas/helix/blob/steel-event-system/steel-docs.md)
- [helix-plugins.com — Lista comunitária de plugins](https://helix-plugins.com/)
- [awesome-helix — Lista curada de recursos](https://github.com/npupko/awesome-helix)
- [Steel — Linguagem Scheme em Rust](https://github.com/mattwparas/steel)
- [PR #8675 — Acompanhe o progresso da integração no Helix oficial](https://github.com/helix-editor/helix/pull/8675)
