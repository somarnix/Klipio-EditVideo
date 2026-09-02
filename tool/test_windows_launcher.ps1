param([string]$Launcher = (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\KlipioLauncher.exe'))
$ErrorActionPreference = 'Stop'
$parent = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\installer\staging'))
$job = Join-Path $parent ('launcher-smoke-' + [guid]::NewGuid().ToString('N'))
$runtime = Join-Path $job 'versions\0.0.0+1-test'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
try {
    Copy-Item -LiteralPath $Launcher -Destination (Join-Path $job 'Klipio.exe')
    '0.0.0+1-test' | Set-Content -LiteralPath (Join-Path $job 'current-package.txt') -Encoding ASCII
    # A controlled child, not the real editor: no user preferences/projects.
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public class KlipioLauncherSmoke {
    public static void Main(string[] args) {
        File.WriteAllLines(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "received.txt"), args);
    }
}
'@ -OutputAssembly (Join-Path $runtime 'Klipio.exe') -OutputType WindowsApplication
    $process = Start-Process -FilePath (Join-Path $job 'Klipio.exe') -ArgumentList '--smoke "project with spaces.klipio"' -WorkingDirectory $env:TEMP -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw 'Root launcher failed.' }
    $result = Join-Path $runtime 'received.txt'
    for ($i=0; $i -lt 50 -and -not (Test-Path -LiteralPath $result); $i++) { Start-Sleep -Milliseconds 100 }
    $actual = @(Get-Content -LiteralPath $result)
    if ($actual.Count -ne 2 -or $actual[0] -ne '--smoke' -or $actual[1] -ne 'project with spaces.klipio') { throw 'Launcher lost arguments or selected the wrong runtime.' }
    Write-Host 'Root launcher smoke passed: version selection, independent working directory, exact argument forwarding.'
} finally {
    if ([IO.Path]::GetFullPath($job).StartsWith($parent+'\', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $job -Recurse -Force
    }
}
