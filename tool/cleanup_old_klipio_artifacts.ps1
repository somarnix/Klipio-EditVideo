$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$ExpectedRoot = 'G:\Klipio EditVideo\Klipio'
$ExpectedParent = 'G:\Klipio EditVideo'
$ExpectedHash = '15b1b6e9c0fedcbe7c2eb46eb1b85f2e86db83b955b06f6f259ed0e12ef469e8'

if (-not [string]::Equals($Root, $ExpectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing cleanup from unexpected source root: $Root"
}

$Installer = Join-Path $Root 'release\Klipio-Windows-Setup.exe'
if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) {
    throw "The surviving full installer is missing: $Installer"
}
$ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Installer).Hash.ToLowerInvariant()
if ($ActualHash -ne $ExpectedHash) {
    throw "The surviving installer checksum is invalid: $ActualHash"
}

$Targets = @(
    (Join-Path $ExpectedParent 'Klipio-fix-backup-20260827'),
    (Join-Path $ExpectedParent 'Klipio-source-before-architecture-20260819-063127.zip'),
    (Join-Path $Root 'release\Klipio-2.0.7-Full-Install'),
    (Join-Path $Root 'release\Klipio-Android.apk'),
    (Join-Path $Root 'release\Klipio-Windows-Setup-2.0.7-20260827.exe'),
    (Join-Path $Root 'release\Klipio-Windows-Setup-2.0.7-20260828.exe'),
    (Join-Path $Root 'release\Klipio-Windows-Setup-2.0.8-20260831.exe'),
    (Join-Path $Root 'release\Klipio-Windows-Setup-2.0.9-20260831.exe'),
    (Join-Path $Root 'build'),
    (Join-Path $Root '.gradle-klipio'),
    (Join-Path $Root '.gradle-user-home'),
    (Join-Path $Root '.pub-cache'),
    (Join-Path $Root 'ffmpeg.zip'),
    (Join-Path $Root 'installer\dist'),
    (Join-Path $Root 'installer\payload'),
    (Join-Path $Root 'installer\KlipioInstaller\bin'),
    (Join-Path $Root 'installer\KlipioInstaller\obj')
)

$ExternalTargets = @(
    (Join-Path $ExpectedParent 'Klipio-fix-backup-20260827'),
    (Join-Path $ExpectedParent 'Klipio-source-before-architecture-20260819-063127.zip')
)
$Report = @()

foreach ($Target in $Targets) {
    $FullPath = [System.IO.Path]::GetFullPath($Target).TrimEnd('\')
    $InsideRoot = $FullPath.StartsWith(
        $Root + '\',
        [System.StringComparison]::OrdinalIgnoreCase
    ) -and -not [string]::Equals(
        $FullPath,
        $Root,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $IsExactExternal = $ExternalTargets | Where-Object {
        [string]::Equals(
            [System.IO.Path]::GetFullPath($_).TrimEnd('\'),
            $FullPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    if (-not $InsideRoot -and -not $IsExactExternal) {
        throw "Refusing unverified cleanup target: $FullPath"
    }
    if (-not (Test-Path -LiteralPath $FullPath)) {
        continue
    }

    $Item = Get-Item -LiteralPath $FullPath -Force
    if ($Item.PSIsContainer) {
        $Measure = Get-ChildItem -LiteralPath $FullPath -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum
        $Bytes = [long]$Measure.Sum
        Remove-Item -LiteralPath $FullPath -Recurse -Force
    }
    else {
        $Bytes = [long]$Item.Length
        Remove-Item -LiteralPath $FullPath -Force
    }
    if (Test-Path -LiteralPath $FullPath) {
        throw "Cleanup target still exists: $FullPath"
    }
    $Report += [pscustomobject]@{
        Removed = $FullPath
        Bytes = $Bytes
        MB = [math]::Round($Bytes / 1MB, 1)
    }
}

$Report | ConvertTo-Json -Depth 3
