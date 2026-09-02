param([int]$MaximumLines = 1000)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'lib'
$oversized = @()
$damaged = @()
$files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.dart')
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
    if ($lines.Count -gt $MaximumLines) {
        $oversized += "$($file.FullName): $($lines.Count) lines"
    }
    if ($lines -match '\d+ tokens truncated') {
        $damaged += $file.FullName
    }
}
$empty = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Directory |
    Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0 })
if ($oversized.Count -or $damaged.Count -or $empty.Count) {
    $oversized | Write-Output
    $damaged | ForEach-Object { Write-Output "Truncated source: $_" }
    $empty | ForEach-Object { Write-Output "Empty directory: $($_.FullName)" }
    exit 1
}
Write-Output "Checked $($files.Count) Dart files: no file exceeds $MaximumLines lines, no truncated source, no empty lib directories."
