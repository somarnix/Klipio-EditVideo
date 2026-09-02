param(
    [string]$InnoCompiler = $env:KLIPIO_ISCC,
    [string]$CaptionPython = $env:KLIPIO_BUILD_PYTHON,
    [string]$MediaDirectory = $env:KLIPIO_BUILD_MEDIA,
    [switch]$RequireSigning
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release_helpers.ps1')
$match = [regex]::Match((Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw), '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
if (-not $match.Success) { throw 'Expected semantic version + build in pubspec.yaml.' }
$version = $match.Groups[1].Value
$buildNumber = $match.Groups[2].Value
$buildId = "$version+$buildNumber"
if (-not $InnoCompiler) { $InnoCompiler = Join-Path $projectRoot 'installer\tools\Inno\ISCC.exe' }
if (-not (Test-Path -LiteralPath $InnoCompiler)) { throw 'Install Inno Setup and set KLIPIO_ISCC.' }
if (-not $CaptionPython) { $CaptionPython = (Get-Command python.exe -ErrorAction Stop).Source }
if (-not $MediaDirectory) {
    $candidates = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'ffmpeg_extracted') -Filter ffmpeg.exe -Recurse -File)
    if ($candidates.Count -ne 1) { throw 'Set KLIPIO_BUILD_MEDIA to the reviewed FFmpeg distribution bin directory.' }
    $MediaDirectory = $candidates[0].DirectoryName
}
if ($RequireSigning -and -not $env:KLIPIO_SIGN_THUMBPRINT) { throw 'Signing identity is required.' }
$job = Join-Path $projectRoot ('installer\staging\' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $job 'app'
$out = Join-Path $job 'output'
New-Item -ItemType Directory -Path $stage,$out -Force | Out-Null
Push-Location $projectRoot
try {
    # No Debug or stale installed application fallback.
    flutter clean
    if ($LASTEXITCODE) { throw 'Flutter clean failed.' }
    flutter pub get
    if ($LASTEXITCODE) { throw 'Flutter restore failed.' }
    # Flutter's registrant lives outside lib/. Give that generated library a
    # package URI so its retained VM entry-point identity is not a developer's
    # absolute file:/// path. This modifies generated build configuration only.
    $packageConfigPath = Join-Path $projectRoot '.dart_tool\package_config.json'
    $packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw | ConvertFrom-Json
    $packageConfig.packages = @($packageConfig.packages | Where-Object { $_.name -ne 'klipio_generated' }) + @([ordered]@{name='klipio_generated';rootUri='flutter_build/';packageUri='';languageVersion='3.5'})
    [IO.File]::WriteAllText($packageConfigPath, ($packageConfig | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
    $symbols = Join-Path $projectRoot ('release\symbols\' + $buildId + '\' + [IO.Path]::GetFileName($job))
    flutter build windows --release --no-pub --obfuscate "--dart-define=KLIPIO_VERSION=$version" "--split-debug-info=$symbols"
    if ($LASTEXITCODE) { throw 'Flutter Release build failed.' }
    $release = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    Copy-Item -LiteralPath (Join-Path $release 'Klipio.exe') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $release 'KlipioLauncher.exe') -Destination $stage
    foreach ($dll in Get-ChildItem -LiteralPath $release -Filter '*.dll' -File) {
        Copy-Item -LiteralPath $dll.FullName -Destination $stage
    }
    # App-local CRT from the actual compiler installation, never System32 or
    # an unrelated installed application's DLLs.
    $generator = (Select-String -LiteralPath (Join-Path $projectRoot 'build\windows\x64\CMakeCache.txt') -Pattern '^CMAKE_GENERATOR_INSTANCE:INTERNAL=(.+)$').Matches[0].Groups[1].Value
    $crt = @(Get-ChildItem -LiteralPath (Join-Path $generator 'VC\Redist\MSVC') -Filter 'Microsoft.VC*.CRT' -Directory -Recurse | Where-Object { $_.FullName -match '\\x64\\' -and $_.FullName -notmatch '\\onecore\\' } | Sort-Object FullName -Descending)
    if ($crt.Count -eq 0) { throw 'Install the compiler-matched x64 Visual C++ redistributable component.' }
    foreach ($dll in Get-ChildItem -LiteralPath $crt[0].FullName -Filter '*.dll' -File) { Copy-Item -LiteralPath $dll.FullName -Destination $stage }
    Copy-Item -LiteralPath (Join-Path $release 'data') -Destination $stage -Recurse
    $native = Join-Path $release 'native_assets.yaml'
    if (Test-Path -LiteralPath $native) { Copy-Item -LiteralPath $native -Destination $stage }
    $media = Join-Path $stage 'runtime\media'
    New-Item -ItemType Directory -Path $media -Force | Out-Null
    foreach ($name in @('ffmpeg.exe','ffprobe.exe')) {
        Copy-Item -LiteralPath (Join-Path $MediaDirectory $name) -Destination $media
        $toolOutput = & (Join-Path $media $name) -version
        if ($LASTEXITCODE) { throw "$name cannot run." }
        $toolOutput | Select-Object -First 1 | Write-Host
    }
    $license = Join-Path (Split-Path $MediaDirectory -Parent) 'LICENSE'
    if (-not (Test-Path -LiteralPath $license)) { throw 'FFmpeg distribution license required.' }
    Copy-Item -LiteralPath $license -Destination (Join-Path $media 'LICENSE.txt')
    & (Join-Path $PSScriptRoot 'stage_caption_runtime.ps1') -Python $CaptionPython -Destination (Join-Path $stage 'runtime\python')
    if ($LASTEXITCODE) { throw 'Caption runtime failed.' }
    Invoke-KlipioSign (Join-Path $stage 'Klipio.exe')
    Invoke-KlipioSign (Join-Path $stage 'KlipioLauncher.exe')
    & (Join-Path $PSScriptRoot 'validate_windows_package.ps1') -Stage $stage -ExpectedVersion $version -ProjectRoot $projectRoot
    $manifest = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path=$_.FullName.Substring($stage.Length+1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes=$_.Length }
    })
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'runtime-manifest.json') -Encoding UTF8
    $packageHash = (Get-FileHash -LiteralPath (Join-Path $stage 'runtime-manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $packageId = "$buildId-$($packageHash.Substring(0,12))"
    # ASCII token consumed by the native root launcher, never an arbitrary path.
    $packagePointer = Join-Path $job 'current-package.txt'
    $packageId | Set-Content -LiteralPath $packagePointer -Encoding ASCII
    $setupName = "Klipio-Windows-Setup-v$buildId"
    $signArgs = @()
    if ($env:KLIPIO_SIGN_THUMBPRINT) {
        $signArgs = @('/DSignRelease=1', ('/SKlipioSign=powershell.exe -NoProfile -ExecutionPolicy Bypass -File $q' + (Join-Path $PSScriptRoot 'sign_windows_binary.ps1') + '$q $f'))
    }
    Add-Type -AssemblyName System.Drawing
    $logo = [Drawing.Image]::FromFile((Join-Path $projectRoot 'assets\branding\KlipioLogo.jpeg'))
    $bitmap = New-Object Drawing.Bitmap 58,58
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $wizardLogo = Join-Path $job 'wizard-logo.bmp'
    try {
        $graphics.Clear([Drawing.Color]::White)
        $ratio = [Math]::Min(58.0 / $logo.Width, 58.0 / $logo.Height)
        $w = [int]($logo.Width * $ratio); $h = [int]($logo.Height * $ratio)
        $graphics.DrawImage($logo, [int]((58-$w)/2), [int]((58-$h)/2), $w, $h)
        $bitmap.Save($wizardLogo, [Drawing.Imaging.ImageFormat]::Bmp)
    } finally { $graphics.Dispose(); $bitmap.Dispose(); $logo.Dispose() }
    & $InnoCompiler "/DAppVersion=$version" "/DBuildNumber=$buildNumber" "/DPackageId=$packageId" "/DPackagePointer=$packagePointer" "/DStage=$stage" "/DOutput=$out" "/DSetupName=$setupName" "/DWizardLogo=$wizardLogo" @signArgs (Join-Path $projectRoot 'installer\Klipio.iss')
    if ($LASTEXITCODE) { throw 'Inno compilation failed.' }
    $setup = Join-Path $out "$setupName.exe"
    Invoke-KlipioSign $setup
    $current = Join-Path $projectRoot 'release\current'
    $archive = Join-Path $projectRoot ('release\archive\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    $hash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $setupName.exe" | Set-Content -LiteralPath (Join-Path $out 'SHA256SUMS.txt') -Encoding ASCII
    [ordered]@{version=$version; build=$buildNumber; packageId=$packageId; sha256=$hash; signed=[bool]$env:KLIPIO_SIGN_THUMBPRINT; mode='Release'; obfuscated=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'release.json') -Encoding UTF8
    New-Item -ItemType Directory -Path $archive -Force | Out-Null
    # Exact generated outputs only; old installers remain recoverable.
    if (Test-Path -LiteralPath $current) { Move-Item -LiteralPath $current -Destination (Join-Path $archive 'current') }
    foreach ($old in @('release\Klipio-Windows-Setup.exe','release\SHA256SUMS.txt')) {
        $oldPath = Join-Path $projectRoot $old
        if (Test-Path -LiteralPath $oldPath) { Move-Item -LiteralPath $oldPath -Destination $archive }
    }
    try { Move-Item -LiteralPath $out -Destination $current }
    catch {
        $previous = Join-Path $archive 'current'
        if ((Test-Path -LiteralPath $previous) -and -not (Test-Path -LiteralPath $current)) { Move-Item -LiteralPath $previous -Destination $current }
        throw
    }
    Write-Host "Installer: $(Join-Path $current "$setupName.exe")"
    Write-Host "SHA256: $hash"
}
finally {
    Pop-Location
    $ownedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'installer\staging')) + '\'
    if ([IO.Path]::GetFullPath($job).StartsWith($ownedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    }
}
