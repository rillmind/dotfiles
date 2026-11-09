<#
.SYNOPSIS
    Lista as atualizações disponíveis (winget + outros gerenciadores) e pergunta quais aplicar.

.DESCRIPTION
    Seleção no estilo do yay/pacman:
        1 2 3 6 9     itens avulsos (vírgula também serve)
        1-4           intervalo
        1-4 7 10-12   misturado
        ^5  ^1-3      exclui (sozinho = todos menos esses)
        a             todos
        Enter         nenhum

    Por padrão o winget roda com --silent, o que dispensa o wizard da maioria
    dos instaladores. O UAC ainda aparece para os que pedem admin, a menos que
    o script já esteja rodando como admin.

.PARAMETER Interactive
    Não passa --silent ao winget (mostra o wizard dos instaladores).

.PARAMETER Background
    Depois de escolher, roda as atualizações numa janela minimizada e libera o terminal.
    O log fica em $env:TEMP\sysupdate.log.

.PARAMETER IncludeUnknown
    Inclui pacotes cuja versão instalada o winget não consegue determinar.

.PARAMETER DryRun
    Só mostra o que seria atualizado.
#>
[CmdletBinding()]
param(
    [switch]$Interactive,
    [switch]$Background,
    [switch]$IncludeUnknown,
    [switch]$DryRun,
    # uso interno: json com a lista já escolhida, repassado para a janela em segundo plano
    [string]$Run
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ellipsis = [string][char]0x2026 # o winget corta colunas longas com isso

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Lê a tabela do `winget upgrade`. Usa a linha de traços como âncora, então não
# depende do idioma do cabeçalho (mesma ideia do winget-prune).
function Get-WingetUpgrades {
    $wargs = @('upgrade', '--accept-source-agreements', '--disable-interactivity')
    if ($IncludeUnknown) { $wargs += '--include-unknown' }
    $lines = @(winget @wargs 2>$null) | ForEach-Object {
        # o spinner do winget usa \r; fica só o que vem depois do último
        $l = [string]$_
        $l.Substring($l.LastIndexOf("`r") + 1).TrimEnd()
    }

    $sep = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($t.Length -gt 10 -and $t.Trim('-') -eq '') { $sep = $i; break }
    }
    if ($sep -lt 1) { return @() }

    # colunas são separadas por 2+ espaços
    $h = $lines[$sep - 1]
    $starts = for ($i = 0; $i -lt $h.Length; $i++) {
        if ($h[$i] -ne ' ' -and ($i -eq 0 -or ($h[$i - 1] -eq ' ' -and ($i -lt 2 -or $h[$i - 2] -eq ' ')))) { $i }
    }
    if ($starts.Count -lt 4) { return @() }

    $col = {
        param($line, $n)
        $s = $starts[$n]
        if ($s -ge $line.Length) { return '' }
        $e = if ($n + 1 -lt $starts.Count) { [Math]::Min($starts[$n + 1], $line.Length) } else { $line.Length }
        $line.Substring($s, $e - $s).Trim()
    }

    foreach ($l in $lines[($sep + 1)..($lines.Count - 1)]) {
        # fim da tabela; depois vêm o resumo e a seção de "explicit targeting"
        if ($l.Trim() -eq '') { break }
        # linhas da tabela têm espaço antes de cada coluna e a última preenchida;
        # o resumo ("N atualizações disponíveis.") às vezes vem colado na tabela
        $isRow = ($l.Length -gt $starts[-1]) -and -not ($starts | Select-Object -Skip 1 | Where-Object { $l[$_ - 1] -ne ' ' })
        if (-not $isRow) { continue }
        $id = & $col $l 1
        if (-not $id) { continue }
        $name = & $col $l 0
        [pscustomobject]@{
            Manager = 'winget'
            Name    = $name
            Id      = $id
            From    = & $col $l 2
            To      = & $col $l 3
        }
    }
}

# Itens "tudo de uma vez" dos outros gerenciadores, só se estiverem instalados.
function Get-OtherManagers {
    $has = { param($c) [bool](Get-Command $c -ErrorAction SilentlyContinue) }
    if (& $has 'scoop') {
        [pscustomobject]@{ Manager = 'scoop'; Name = 'Apps do Scoop'; Id = 'scoop update *'; From = ''; To = '' }
    }
    if (& $has 'npm') {
        [pscustomobject]@{ Manager = 'npm'; Name = 'Pacotes globais do npm'; Id = 'npm update -g'; From = ''; To = '' }
    }
    if (& $has 'cargo') {
        [pscustomobject]@{ Manager = 'cargo'; Name = 'Binários do cargo'; Id = 'cargo install-update -a'; From = ''; To = '' }
    }
    if (& $has 'uv') {
        [pscustomobject]@{ Manager = 'uv'; Name = 'Ferramentas do uv'; Id = 'uv tool upgrade --all'; From = ''; To = '' }
    }
}

# Converte "1-4 7 ^3" em índices (base 1). Devolve $null se a entrada for inválida.
# O retorno usa `,` para o array vazio não virar $null.
function Resolve-Selection([string]$text, [int]$max) {
    $text = $text.Trim().ToLower()
    if ($text -eq '') { return , [int[]]@() }
    if ($text -in 'a', 'all', 'todos', '*') { return , [int[]](1..$max) }

    $include = [Collections.Generic.HashSet[int]]::new()
    $exclude = [Collections.Generic.HashSet[int]]::new()
    foreach ($tok in $text -split '[\s,]+' | Where-Object { $_ }) {
        $neg = $tok.StartsWith('^')
        if ($neg) { $tok = $tok.Substring(1) }
        if ($tok -match '^(\d+)-(\d+)$') {
            $a, $b = [int]$Matches[1], [int]$Matches[2]
            if ($a -gt $b) { $a, $b = $b, $a }
            $range = $a..$b
        } elseif ($tok -match '^\d+$') {
            $range = @([int]$tok)
        } else {
            Write-Host "  não entendi '$tok'" -ForegroundColor Yellow
            return $null
        }
        foreach ($n in $range) {
            if ($n -lt 1 -or $n -gt $max) {
                Write-Host "  $n está fora da lista (1-$max)" -ForegroundColor Yellow
                return $null
            }
            [void]$(if ($neg) { $exclude.Add($n) } else { $include.Add($n) })
        }
    }
    # só exclusões = todos menos esses
    if ($include.Count -eq 0) { 1..$max | ForEach-Object { [void]$include.Add($_) } }
    , [int[]]@($include | Where-Object { -not $exclude.Contains($_) } | Sort-Object)
}

function Invoke-Update($item) {
    Write-Step "$($item.Name) ($($item.Manager))"
    switch ($item.Manager) {
        'winget' {
            # id truncado: cai para o nome; se os dois vieram truncados, não há como
            if (-not $item.Id.EndsWith($ellipsis)) { $target = '--id', $item.Id }
            elseif (-not $item.Name.EndsWith($ellipsis)) { $target = '--name', $item.Name }
            else { Write-Host '    pulado: id e nome truncados pelo winget' -ForegroundColor Yellow; return $false }

            $wargs = @('upgrade') + $target + @('-e', '--accept-source-agreements', '--accept-package-agreements')
            if (-not $Interactive) { $wargs += '--silent', '--disable-interactivity' }
            winget @wargs
        }
        'scoop' { scoop update; scoop update * }
        'npm'   { npm update -g }
        'cargo' { cargo install-update -a }
        'uv'    { uv tool upgrade --all }
    }
    $ok = $LASTEXITCODE -eq 0
    if (-not $ok) { Write-Host "    falhou (código $LASTEXITCODE)" -ForegroundColor Red }
    $ok
}

function Invoke-Updates($items) {
    $failed = @()
    foreach ($item in $items) {
        if (-not (Invoke-Update $item)) { $failed += $item }
    }
    Write-Host ''
    if ($failed) {
        Write-Host "Terminado com $($failed.Count) falha(s):" -ForegroundColor Yellow
        $failed | ForEach-Object { Write-Host "  - $($_.Name) ($($_.Id))" }
    } else {
        Write-Host 'Tudo atualizado.' -ForegroundColor Green
    }
}

# --- modo segundo plano: recebe a lista já escolhida e só executa ---
if ($Run) {
    $log = Join-Path $env:TEMP 'sysupdate.log'
    Start-Transcript -Path $log | Out-Null
    Invoke-Updates (Get-Content $Run -Raw | ConvertFrom-Json)
    Remove-Item $Run
    Stop-Transcript | Out-Null
    return
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error 'winget não encontrado.'
    exit 1
}

Write-Host 'Procurando atualizações...' -ForegroundColor Cyan
$items = @(Get-WingetUpgrades | Sort-Object { $_.Name.ToLower() }) + @(Get-OtherManagers)
if ($items.Count -eq 0) {
    Write-Host 'Nada para atualizar.' -ForegroundColor Green
    return
}

$w = [Math]::Min(40, ($items | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)
$pad = $items.Count.ToString().Length
Write-Host ''
for ($i = 0; $i -lt $items.Count; $i++) {
    $it = $items[$i]
    $name = if ($it.Name.Length -gt $w) { $it.Name.Substring(0, $w - 1) + $ellipsis } else { $it.Name.PadRight($w) }
    Write-Host ("{0,$pad}) " -f ($i + 1)) -NoNewline -ForegroundColor Cyan
    Write-Host "$name  " -NoNewline
    if ($it.Manager -eq 'winget') {
        Write-Host $it.From -NoNewline -ForegroundColor DarkGray
        Write-Host ' -> ' -NoNewline
        Write-Host $it.To -ForegroundColor Green
    } else {
        Write-Host "[$($it.Manager)] $($it.Id)" -ForegroundColor Yellow
    }
}

Write-Host "`nQuais atualizar? (ex: 1-4  |  1 2 3 6 9  |  ^5 = todos menos o 5  |  a = todos  |  Enter = nenhum)"
do {
    $sel = Resolve-Selection (Read-Host '>') $items.Count
} while ($null -eq $sel)

$chosen = @($sel | ForEach-Object { $items[$_ - 1] })
if ($chosen.Count -eq 0) {
    Write-Host 'Nada selecionado.'
    return
}

Write-Host "`nVão ser atualizados:"
$chosen | ForEach-Object { Write-Host "  - $($_.Name)" }

if ($DryRun) {
    Write-Host "`n(dry-run: nada foi atualizado)"
    return
}

if (-not (Test-Admin)) {
    Write-Host "`nDica: rodando sem admin, cada instalador que precisar de admin vai abrir um UAC." -ForegroundColor DarkGray
}

$ans = Read-Host "`nConfirmar? [S/n]"
if ($ans.Trim().ToLower() -notin '', 's', 'y') {
    Write-Host 'Cancelado.'
    return
}

if ($Background) {
    $queue = Join-Path $env:TEMP 'sysupdate-queue.json'
    ConvertTo-Json @($chosen) | Set-Content $queue -Encoding utf8
    $passArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Run', "`"$queue`"")
    if ($Interactive) { $passArgs += '-Interactive' }
    Start-Process pwsh -WindowStyle Minimized -ArgumentList $passArgs
    Write-Host "Rodando em segundo plano (janela minimizada). Log: $(Join-Path $env:TEMP 'sysupdate.log')" -ForegroundColor Green
    return
}

Invoke-Updates $chosen
