param([Parameter(Mandatory=$true)][string]$File)
$ErrorActionPreference = 'Stop'
if (-not $env:KLIPIO_SIGN_THUMBPRINT) { throw 'No legitimate signing identity configured.' }
$tool = $env:KLIPIO_SIGNTOOL
if (-not $tool) { $tool = (Get-Command signtool.exe -ErrorAction Stop).Source }
if (-not $env:KLIPIO_TIMESTAMP_URL) { throw 'Configure KLIPIO_TIMESTAMP_URL for RFC3161 timestamping.' }
& $tool sign /sha1 $env:KLIPIO_SIGN_THUMBPRINT /fd SHA256 /tr $env:KLIPIO_TIMESTAMP_URL /td SHA256 $File
if ($LASTEXITCODE) { throw 'SignTool failed.' }
& $tool verify /pa $File
if ($LASTEXITCODE) { throw 'Authenticode verification failed.' }
