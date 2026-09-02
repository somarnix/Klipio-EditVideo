param(
    [Parameter(Mandatory=$true)][string]$Stage,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ProjectRoot
)
$ErrorActionPreference = 'Stop'
$stageRoot = (Resolve-Path -LiteralPath $Stage).Path
# Refuse to publish a build while the editor source is still being changed.
# AOT can finish after a source edit even though its input kernel is older.
$kernelRoot = Join-Path $ProjectRoot '.dart_tool\flutter_build'
if (Test-Path -LiteralPath $kernelRoot) {
    $kernel = Get-ChildItem -LiteralPath $kernelRoot -Recurse -Filter app.dill -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($kernel) {
        $changedSource = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'lib') -Recurse -Filter '*.dart' -File | Where-Object { $_.LastWriteTimeUtc -gt $kernel.LastWriteTimeUtc } | Select-Object -First 1
        if ($changedSource) { throw "Source changed after compilation: $($changedSource.FullName). Rebuild before packaging." }
    }
}
$required = @('Klipio.exe','flutter_windows.dll','video_player_win_plugin.dll','audioplayers_windows_plugin.dll','desktop_drop_plugin.dll','data\app.so','data\icudtl.dat','data\flutter_assets\AssetManifest.bin','runtime\media\ffmpeg.exe','runtime\media\ffprobe.exe','runtime\media\LICENSE.txt','runtime\python\python.exe','runtime\python\python312._pth','runtime\python\python312.zip','runtime\python\dependencies.json')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $stageRoot $name) -PathType Leaf)) { throw "Required runtime missing: $name" }
}
if (-not (Test-Path -LiteralPath (Join-Path $stageRoot 'KlipioLauncher.exe') -PathType Leaf)) { throw 'Required root launcher missing.' }
foreach ($name in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $stageRoot $name))) { throw "Missing app-local Visual C++ runtime: $name" }
}
$info = (Get-Item -LiteralPath (Join-Path $stageRoot 'Klipio.exe')).VersionInfo
if (-not $info.ProductVersion.StartsWith($ExpectedVersion) -or $info.CompanyName -ne 'Somarnix' -or $info.IsDebug) { throw 'EXE version, publisher or Release metadata mismatch.' }
$forbidden = '(?i)(^|/)(\.git|\.github|\.vscode|\.idea|test|tests|tool|Knowledge|__pycache__)(/|$)|(^|/)(README[^/]*|Project\.md|\.env(?:\..*)?|[^/]*\.(dart|pdb|log|pfx|p12|key)|kernel_blob\.bin|vm_snapshot_data|isolate_snapshot_data)$'
$paths = @($ProjectRoot, $env:USERPROFILE) | Where-Object { $_ }
$needles = @($paths | ForEach-Object { [regex]::Escape($_); [regex]::Escape($_.Replace('\','/')) })
$privateProfile = '(?i)[a-z]:[\\/]Users[\\/](?!<user>)[^\\/\x00\r\n]+[\\/]'
# These exact upstream artifacts contain CPython's documented Barney example
# or the public wheel CI account runneradmin. They are not Klipio developer
# paths or runtime lookups. Never patch/sign upstream DLL bytes to hide them.
# Any changed artifact needs review; local project/user paths always fail.
$upstreamDiagnostics = @{
    'runtime/python/python312.dll' = '789A42AC160CEF98F8925CB347473EEEB4E70F5513242E7FABA5139BA06EDF2D'
    'runtime/python/Lib/site-packages/numpy/__config__.py' = 'EB23E31078A9D648764F588CBC319076ADA076097A6E91B5A1424590F7235A89'
    'runtime/python/Lib/site-packages/tokenizers/tokenizers.cp312-win_amd64.pyd' = 'E41443D02ADC75B361C75110E5BEA725EE3BF5526CB8A1B45E848ECE9145CD7D'
}
$secret = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|(?:api_secret|private_key|database_password)\s*[:=]\s*["''][^"'']{12,}'
foreach ($file in Get-ChildItem -LiteralPath $stageRoot -Recurse -File) {
    $relative = $file.FullName.Substring($stageRoot.Length+1).Replace('\','/')
    if ($relative -match $forbidden) { throw "Forbidden production artifact: $relative" }
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unresolved runtime link: $relative" }
    # Stream every file, including PE/AOT data. Chunk overlap detects patterns
    # split across buffers without retaining whole videos/models in memory.
    $stream = $file.OpenRead()
    $reviewed = $false
    if ($upstreamDiagnostics.ContainsKey($relative)) {
        $reviewed = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -eq $upstreamDiagnostics[$relative]
    }
    try {
        $buffer = New-Object byte[] (1024*1024)
        $previous = ''
        while (($count = $stream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $text = $previous + [Text.Encoding]::UTF8.GetString($buffer,0,$count)
            $search = $text.Replace([string][char]0,'')
            if ($search -match ($needles -join '|')) { throw "Developer path in package: $relative" }
            if ($search -match $privateProfile -and -not $reviewed) { throw "Unreviewed developer profile path: $relative" }
            if ($file.Extension -in @('.pem','.json','.yaml','.yml','.txt','.py','.ini','.cfg') -and $search -match $secret) { throw "Potential secret in package: $relative" }
            $previous = $text.Substring([Math]::Max(0,$text.Length-512))
        }
    } finally { $stream.Dispose() }
}
Write-Host 'Release staging validation passed.'
