param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$VersionLine = Select-String -LiteralPath (Join-Path $Root 'pubspec.yaml') -Pattern '^version:' | Select-Object -First 1
if (-not $VersionLine) {
    throw 'Could not read version from pubspec.yaml.'
}

$Version = ($VersionLine.Line -replace '^version:\s*', '') -replace '\+.*$', ''
$DateStamp = Get-Date -Format 'yyyyMMdd'
$ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$PayloadDir = Join-Path $Root 'installer\payload'
$PayloadZip = Join-Path $PayloadDir "KlipioApp-v$Version-installer-runtime.zip"
$InstallerProject = Join-Path $Root 'installer\KlipioInstaller\KlipioInstaller.csproj'
$InstallerDist = Join-Path $Root "installer\dist\v$Version-$DateStamp"
$ReleaseOut = Join-Path $Root 'release'
$SetupExe = Join-Path $InstallerDist 'KlipioSetup.exe'
$ReleaseSetup = Join-Path $ReleaseOut 'Klipio-Windows-Setup.exe'
$ChecksumFile = Join-Path $ReleaseOut 'SHA256SUMS.txt'

Write-Host "============================================================"
Write-Host "  KLIPIO $Version - FULL WINDOWS SETUP BUILDER"
Write-Host "============================================================"

Push-Location $Root
try {
    if ($SkipFlutterBuild) {
        Write-Host "[1/6] Using the existing Windows release build..."
        Write-Host "[2/6] Flutter build skipped by request."
    }
    else {
        Write-Host "[1/6] Restoring Flutter packages..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw 'Flutter package restore failed.'
        }

        Write-Host "[2/6] Building Windows release app..."
        flutter build windows
        if ($LASTEXITCODE -ne 0) {
            throw 'Flutter Windows build failed.'
        }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $ReleaseDir 'Klipio.exe'))) {
        throw 'Flutter build did not create Klipio.exe.'
    }

    Write-Host "[3/6] Checking FFmpeg runtime files..."
    foreach ($ToolName in @('ffmpeg.exe', 'ffprobe.exe')) {
        $Target = Join-Path $ReleaseDir $ToolName
        if (-not (Test-Path -LiteralPath $Target)) {
            $Source = Join-Path $Root "ffmpeg_extracted\$ToolName"
            if (Test-Path -LiteralPath $Source) {
                Copy-Item -LiteralPath $Source -Destination $Target -Force
            }
        }
        if (-not (Test-Path -LiteralPath $Target)) {
            $InstalledSource = Join-Path $env:LOCALAPPDATA "Programs\Klipio\$ToolName"
            if (Test-Path -LiteralPath $InstalledSource) {
                Copy-Item -LiteralPath $InstalledSource -Destination $Target -Force
            }
        }
        if (-not (Test-Path -LiteralPath $Target)) {
            throw "$ToolName was not found in the Windows runtime."
        }
    }

    Write-Host "[4/6] Packing complete app runtime..."
    New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null
    if (Test-Path -LiteralPath $PayloadZip) {
        Remove-Item -LiteralPath $PayloadZip -Force
    }
    $Items = @(Get-ChildItem -LiteralPath $ReleaseDir -Force | Where-Object { $_.Name -ne 'klipio.msix' })
    if ($Items.Count -eq 0) {
        throw 'No Windows runtime files were found to package.'
    }
    Compress-Archive -Path $Items.FullName -DestinationPath $PayloadZip -CompressionLevel Optimal

    Write-Host "[5/6] Publishing self-contained setup EXE..."
    dotnet publish $InstallerProject -c Release -r win-x64 --self-contained true -o $InstallerDist
    if (-not (Test-Path -LiteralPath $SetupExe)) {
        throw 'Installer publish did not create KlipioSetup.exe.'
    }

    Write-Host "[6/6] Publishing release files and checksum..."
    New-Item -ItemType Directory -Force -Path $ReleaseOut | Out-Null
    Copy-Item -LiteralPath $SetupExe -Destination $ReleaseSetup -Force
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ReleaseSetup).Hash.ToLowerInvariant()
    $Lines = @("$Hash  Klipio-Windows-Setup.exe")
    Set-Content -LiteralPath $ChecksumFile -Value $Lines -Encoding ASCII

    Write-Host ""
    Write-Host "BUILD COMPLETE"
    Write-Host "Installer: $ReleaseSetup"
    Write-Host "SHA256: $Hash"
}
finally {
    Pop-Location
}
