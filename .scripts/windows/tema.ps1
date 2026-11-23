#Requires -Version 7
<#
.SYNOPSIS
    Inicia e troca os temas da área de trabalho, como o tema.sh do quickshell no Linux.

.DESCRIPTION
    catppuccin       barra no topo pelo YASB (~/.config/yasb)
    gruvbox-escuro   barra lateral pelo Zebar (~/.glzr/zebar/gruvbox) + contorno arredondado
    gruvbox-claro    o mesmo, com a paleta clara

    O contorno do Gruvbox fica atrás das janelas, então vira o papel de parede: a imagem base com
    a moldura desenhada por cima. As janelas ficam dentro dele pelos gaps externos do GlazeWM.
    O tema escolhido fica salvo e volta no próximo login (initSystem.ps1 chama "iniciar").

.EXAMPLE
    tema.ps1                  alterna entre catppuccin e gruvbox
    tema.ps1 gruvbox-claro    troca para um tema específico
    tema.ps1 iniciar          sobe o tema salvo (login)
#>
param(
    [ValidateSet('iniciar', 'catppuccin', 'gruvbox', 'gruvbox-escuro', 'gruvbox-claro', 'ativo')]
    [string]$Tema
)

$Estado   = Join-Path $env:LOCALAPPDATA 'tema'
$Glazewm  = Join-Path $HOME '.glzr\glazewm\config.yaml'
$Zebar    = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$Walls    = Join-Path $HOME 'Nextcloud\Imagens\Wallpapers'
New-Item -ItemType Directory -Force $Estado | Out-Null

# Medidas do Gruvbox/shell.qml: barra 46, contorno 14, cantos 16. Gap das janelas: 10.
$Barra = 46; $Contorno = 14; $Raio = 16; $Gap = 10
$Cores = @{ 'gruvbox-escuro' = '#1d2021'; 'gruvbox-claro' = '#f9f5d7' }

function Get-Salvo([string]$Nome, [string]$Padrao) {
    $f = Join-Path $Estado $Nome
    if (Test-Path $f) { (Get-Content $f -Raw).Trim() } else { $Padrao }
}
function Set-Salvo([string]$Nome, [string]$Valor) { Set-Content (Join-Path $Estado $Nome) $Valor -NoNewline }

Add-Type -Namespace Win32 -Name Desktop -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
'@
function Set-PapelDeParede([string]$Arquivo) {
    # 0x14 = SPI_SETDESKWALLPAPER; 3 = grava no perfil e avisa os apps
    [void][Win32.Desktop]::SystemParametersInfo(0x14, 0, $Arquivo, 3)
}

# Papel de parede do Gruvbox: imagem base cortada para a tela + moldura com o recorte arredondado.
function New-PapelGruvbox([string]$Modo) {
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms
    $tela = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $base = Get-Salvo 'wallpaper-gruvbox' (Join-Path $Walls 'blobs-d.png')
    $saida = Join-Path $Estado "wallpaper-$Modo.png"

    $img = [System.Drawing.Image]::FromFile($base)
    $bmp = [System.Drawing.Bitmap]::new($tela.Width, $tela.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'

    # preenche a tela mantendo a proporção (corta o que sobrar)
    $esc = [Math]::Max($tela.Width / $img.Width, $tela.Height / $img.Height)
    $w = $img.Width * $esc; $h = $img.Height * $esc
    $g.DrawImage($img, ($tela.Width - $w) / 2, ($tela.Height - $h) / 2, $w, $h)

    # moldura = tela inteira menos o retângulo arredondado da área das janelas
    $x0 = $Barra; $y0 = $Contorno; $x1 = $tela.Width - $Contorno; $y1 = $tela.Height - $Contorno; $d = $Raio * 2
    $recorte = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $recorte.AddArc($x0, $y0, $d, $d, 180, 90)
    $recorte.AddArc($x1 - $d, $y0, $d, $d, 270, 90)
    $recorte.AddArc($x1 - $d, $y1 - $d, $d, $d, 0, 90)
    $recorte.AddArc($x0, $y1 - $d, $d, $d, 90, 90)
    $recorte.CloseFigure()
    $moldura = [System.Drawing.Region]::new([System.Drawing.Rectangle]::new(0, 0, $tela.Width, $tela.Height))
    $moldura.Exclude($recorte)
    $g.FillRegion([System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Cores[$Modo])), $moldura)

    $bmp.Save($saida, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    $saida
}

# Gaps externos do GlazeWM: no Gruvbox somam o contorno (a barra lateral já reserva a esquerda).
function Set-Gaps([int]$Topo, [int]$Direita, [int]$Baixo, [int]$Esquerda) {
    $c = Get-Content $Glazewm -Raw
    $novo = [regex]::Replace($c, '(?ms)(outer_gap:\s*\n\s*top: ")\d+(px"\s*\n\s*right: ")\d+(px"\s*\n\s*bottom: ")\d+(px"\s*\n\s*left: ")\d+(px")',
        "`${1}$Topo`${2}$Direita`${3}$Baixo`${4}$Esquerda`${5}")
    if ($novo -ne $c) {
        Set-Content $Glazewm $novo -NoNewline
        if (Get-Process glazewm -ErrorAction SilentlyContinue) { glazewm command wm-reload-config | Out-Null }
    }
}

# Modo de cor do Windows (a barra do Zebar segue o tema dos apps via prefers-color-scheme).
function Set-ModoWindows([bool]$Claro) {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty $k AppsUseLightTheme ([int]$Claro)
    Set-ItemProperty $k SystemUsesLightTheme ([int]$Claro)
}

function Stop-Barras {
    Get-Process yasb, zebar -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
}

function Start-Tema([string]$Nome) {
    $atual = Get-Salvo 'ativo' 'catppuccin'
    # o papel de parede do Catppuccin é o que estava em uso ao sair dele
    if ($atual -eq 'catppuccin' -and $Nome -ne 'catppuccin') {
        Set-Salvo 'wallpaper-catppuccin' (Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper
    }
    Stop-Barras
    if ($Nome -eq 'catppuccin') {
        Set-ModoWindows $false
        Set-Gaps $Gap $Gap $Gap $Gap
        $wall = Get-Salvo 'wallpaper-catppuccin' (Join-Path $Walls "gato-n'gua1-blase.jpg")
        if ($wall -and (Test-Path -LiteralPath $wall)) { Set-PapelDeParede $wall }
        Start-Process yasb
    } else {
        Set-ModoWindows ($Nome -eq 'gruvbox-claro')
        Set-Gaps ($Contorno + $Gap) ($Contorno + $Gap) ($Contorno + $Gap) $Gap
        Set-PapelDeParede (New-PapelGruvbox $Nome)
        Start-Process $Zebar -ArgumentList 'start-widget-preset', '--pack', 'gruvbox', '--widget-name', 'barra-lateral', '--preset', 'default'
    }
    Set-Salvo 'ativo' $Nome
    "tema: $Nome"
}

switch ($Tema) {
    'ativo'   { Get-Salvo 'ativo' 'catppuccin' }
    'iniciar' { Start-Tema (Get-Salvo 'ativo' 'catppuccin') }
    'gruvbox' { Start-Tema 'gruvbox-escuro' }
    ''        { Start-Tema $(if ((Get-Salvo 'ativo' 'catppuccin') -eq 'catppuccin') { 'gruvbox-escuro' } else { 'catppuccin' }) }
    default   { Start-Tema $Tema }
}
