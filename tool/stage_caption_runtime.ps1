param(
    [Parameter(Mandatory=$true)][string]$Python,
    [Parameter(Mandatory=$true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$pythonRoot = Split-Path (Resolve-Path -LiteralPath $Python).Path -Parent
$metadata = & $Python -c "import sys; print(str(sys.version_info.major)+str(sys.version_info.minor))"
if ($LASTEXITCODE -or $metadata -ne '312') { throw 'Reviewed caption dependencies currently require CPython 3.12 x64.' }
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
foreach ($name in @('python.exe','python3.dll','python312.dll','vcruntime140.dll','vcruntime140_1.dll','LICENSE.txt')) {
    Copy-Item -LiteralPath (Join-Path $pythonRoot $name) -Destination $Destination
}
# Zip only standard-library runtime code: no pip, development environment,
# bytecode carrying developer paths, test suites, Tcl/Tk or caches.
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::Open((Join-Path $Destination 'python312.zip'), [IO.Compression.ZipArchiveMode]::Create)
try {
    $stdlib = Join-Path $pythonRoot 'Lib'
    foreach ($file in Get-ChildItem -LiteralPath $stdlib -Recurse -File -Filter '*.py') {
        $relative = $file.FullName.Substring($stdlib.Length+1).Replace('\','/')
        if ($relative -match '(^|/)(site-packages|test|tests|__pycache__|idlelib|tkinter|turtledemo|ensurepip|venv)(/|$)') { continue }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative) | Out-Null
    }
} finally { $zip.Dispose() }
$dllTarget = Join-Path $Destination 'DLLs'
New-Item -ItemType Directory -Path $dllTarget -Force | Out-Null
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $pythonRoot 'DLLs') -File) {
    if ($file.Extension -notin @('.pyd','.dll')) { continue }
    if ($file.Name -match '^(_test|_tkinter|tcl|tk)') { continue }
    Copy-Item -LiteralPath $file.FullName -Destination $dllTarget
}
@('python312.zip','DLLs','Lib/site-packages','.','import site') | Set-Content -LiteralPath (Join-Path $Destination 'python312._pth') -Encoding ASCII
# Distribution RECORDs define the dependency closure. Never copy site-packages
# wholesale, entry-point scripts, pip caches, editable installs or user config.
$metadataScript = @'
import json
from importlib.metadata import distribution
from packaging.requirements import Requirement
pending, seen, files, versions = ['faster-whisper'], set(), [], {}
while pending:
    name = pending.pop()
    key = name.lower().replace('_', '-')
    if key in seen: continue
    seen.add(key)
    dist = distribution(name)
    versions[name] = dist.version
    for requirement in dist.requires or []:
        parsed = Requirement(requirement)
        if parsed.marker is None or parsed.marker.evaluate({'extra': ''}):
            pending.append(parsed.name)
    for entry in dist.files or []:
        if '..' in entry.parts: continue
        if any(p.lower() in ('tests','test','__pycache__','docs','examples','benchmarks') for p in entry.parts): continue
        if entry.suffix.lower() in ('.pyc','.pyo','.pdb','.lib','.h','.c','.cpp'): continue
        if entry.name.lower().startswith(('readme','direct_url')): continue
        source = dist.locate_file(entry)
        if source.is_file(): files.append({'source':str(source), 'relative':str(entry)})
print(json.dumps({'files':files,'versions':versions}))
'@
$raw = & $Python -c $metadataScript
if ($LASTEXITCODE) { throw 'Caption dependency discovery failed.' }
$manifest = $raw | ConvertFrom-Json
$locked = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'caption_runtime.lock.json') -Raw | ConvertFrom-Json
foreach ($dependency in $manifest.versions.PSObject.Properties) {
    $expected = $locked.PSObject.Properties[$dependency.Name]
    if (-not $expected -or $expected.Value -ne $dependency.Value) { throw "Unreviewed caption dependency: $($dependency.Name) $($dependency.Value)" }
}
if (@($locked.PSObject.Properties).Count -ne @($manifest.versions.PSObject.Properties).Count) { throw 'Caption dependency closure changed.' }
$packages = Join-Path $Destination 'Lib\site-packages'
foreach ($file in $manifest.files) {
    $target = Join-Path $packages $file.relative
    if (-not [IO.Path]::GetFullPath($target).StartsWith([IO.Path]::GetFullPath($packages)+'\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe dependency path.' }
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $target -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'caption_sitecustomize.py') -Destination (Join-Path $packages 'sitecustomize.py')
$modelName = 'models--Systran--faster-whisper-base.en'
$modelSource = Join-Path $env:USERPROFILE ".cache\huggingface\hub\$modelName"
if (-not (Test-Path -LiteralPath $modelSource)) { throw 'Default offline base.en model must be available in build cache.' }
New-Item -ItemType Directory -Path (Join-Path $Destination 'models') -Force | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $modelSource -File -Recurse) {
    $relative = $file.FullName.Substring($modelSource.Length+1)
    # Snapshot files are copied as real files, so the duplicate hub blob store
    # and download bookkeeping are not runtime dependencies.
    if ($relative -notmatch '^(refs|snapshots)\\') { continue }
    if ($relative -match '(^|\\)(README[^\\]*|\.gitattributes|\.cache)(\\|$)') { continue }
    $target = Join-Path (Join-Path $Destination "models\$modelName") $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target
}
$manifest.versions | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination 'dependencies.json') -Encoding UTF8
$oldLocal = $env:LOCALAPPDATA
$verifyData = Join-Path (Split-Path $Destination -Parent) ('.verify-userdata-' + [guid]::NewGuid().ToString('N'))
try {
    $env:LOCALAPPDATA = $verifyData
    & (Join-Path $Destination 'python.exe') -I -B -c "import faster_whisper, ctranslate2, av, onnxruntime; faster_whisper.WhisperModel('base.en', device='cpu', compute_type='int8', local_files_only=True); print('Offline caption runtime OK')"
    if ($LASTEXITCODE) { throw 'Isolated caption runtime cannot load the offline model.' }
} finally {
    $env:LOCALAPPDATA = $oldLocal
    $parent = [IO.Path]::GetFullPath((Split-Path $Destination -Parent)) + '\'
    if ([IO.Path]::GetFullPath($verifyData).StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $verifyData)) {
        Remove-Item -LiteralPath $verifyData -Recurse -Force
    }
}
