<#
  Renders a REAL run of setup.ps1 (with its colours) into docs/screenshot.svg for the README.
  No extra tools needed: Write-Host output carries its colour, so we capture it and draw an SVG.

  ./tools/New-Screenshot.ps1                                   # default: core,terminal,web -Plan
  ./tools/New-Screenshot.ps1 -Arguments '-Category all -Plan'  # any other run
#>
param(
    [string]$Arguments = '-Category core,terminal,web -Plan',
    [string]$OutFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/screenshot.svg'),
    [int]$MaxLines = 40
)

$root = Split-Path $PSScriptRoot -Parent

# Terminal colours (Catppuccin Mocha-like) for the ConsoleColor values setup.ps1 uses
$palette = @{
    Default  = '#cdd6f4'; Cyan = '#89dceb'; DarkGray = '#7f849c'; Yellow = '#f9e2af'
    Green    = '#a6e3a1'; Red  = '#f38ba8'; Gray     = '#bac2de'; White  = '#ffffff'
}

# 1) Run setup.ps1 and capture each Write-Host message (stream 6) together with its colour
# (A plain string array would pass '-Category' as a value, so let PowerShell parse the
#  arguments exactly as if they were typed. $Arguments comes from the maintainer running this.)
$setup = Join-Path $root 'setup.ps1'
$records = & ([scriptblock]::Create("& '$setup' $Arguments 6>&1"))

# 2) Rebuild the screen as lines made of coloured pieces (Write-Host -NoNewline joins pieces)
$lines = [System.Collections.Generic.List[object]]::new()
$current = [System.Collections.Generic.List[object]]::new()
foreach ($r in $records) {
    $msg = $r.MessageData
    $text  = if ($msg -is [System.Management.Automation.HostInformationMessage]) { $msg.Message } else { "$msg" }
    $color = if ($msg.ForegroundColor) { "$($msg.ForegroundColor)" } else { 'Default' }
    $parts = $text -split "`n"
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i -gt 0) { $lines.Add($current); $current = [System.Collections.Generic.List[object]]::new() }
        if ($parts[$i]) { $current.Add([pscustomobject]@{ Text = $parts[$i]; Color = $color }) }
    }
    if (-not $msg.NoNewLine) { $lines.Add($current); $current = [System.Collections.Generic.List[object]]::new() }
}
if ($current.Count) { $lines.Add($current) }

# Prompt line on top, like a real terminal
$prompt = [System.Collections.Generic.List[object]]::new()
$prompt.Add([pscustomobject]@{ Text = 'PS> '; Color = 'Green' })
$prompt.Add([pscustomobject]@{ Text = ".\setup.ps1 $Arguments"; Color = 'White' })
$lines.Insert(0, $prompt)
if ($lines.Count -gt $MaxLines) { $lines = $lines.GetRange(0, $MaxLines) }

# 3) Draw the SVG
$fontSize = 14; $lineHeight = 20; $charWidth = 8.4; $padX = 20; $top = 52
$longest = ($lines | ForEach-Object { ($_ | ForEach-Object Text) -join '' } | Measure-Object -Property Length -Maximum).Maximum
$width  = [int]([Math]::Max(640, $padX * 2 + $longest * $charWidth))
$height = $top + $lines.Count * $lineHeight + 16

# Escape for XML, and turn spaces into non-breaking spaces: browsers collapse normal
# spaces in SVG text, which would break the column alignment
function ConvertTo-XmlText([string]$s) { [System.Security.SecurityElement]::Escape($s).Replace(' ', '&#160;') }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$width`" height=`"$height`" viewBox=`"0 0 $width $height`">")
[void]$sb.AppendLine("  <rect width=`"$width`" height=`"$height`" rx=`"10`" fill=`"#1e1e2e`"/>")
[void]$sb.AppendLine("  <circle cx=`"22`" cy=`"20`" r=`"6`" fill=`"#f38ba8`"/><circle cx=`"42`" cy=`"20`" r=`"6`" fill=`"#f9e2af`"/><circle cx=`"62`" cy=`"20`" r=`"6`" fill=`"#a6e3a1`"/>")
[void]$sb.AppendLine("  <text x=`"$($width / 2)`" y=`"25`" fill=`"#7f849c`" font-family=`"Segoe UI, sans-serif`" font-size=`"13`" text-anchor=`"middle`">windows-dev-setup</text>")
[void]$sb.AppendLine("  <g font-family=`"Cascadia Mono, Consolas, Menlo, monospace`" font-size=`"$fontSize`" xml:space=`"preserve`" style=`"white-space:pre`">")  # keep spaces (browsers ignore xml:space)
$y = $top
foreach ($line in $lines) {
    if ($line.Count) {
        [void]$sb.Append("    <text x=`"$padX`" y=`"$y`">")
        foreach ($piece in $line) {
            $fill = if ($palette[$piece.Color]) { $palette[$piece.Color] } else { $palette.Default }
            [void]$sb.Append("<tspan fill=`"$fill`">$(ConvertTo-XmlText $piece.Text)</tspan>")
        }
        [void]$sb.AppendLine('</text>')
    }
    $y += $lineHeight
}
[void]$sb.AppendLine('  </g>')
[void]$sb.AppendLine('</svg>')

New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
[IO.File]::WriteAllText($OutFile, $sb.ToString())
Write-Host "Saved $OutFile ($($lines.Count) lines)" -ForegroundColor Green
