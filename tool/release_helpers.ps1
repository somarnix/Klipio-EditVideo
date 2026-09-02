function Invoke-KlipioSign([string]$File) {
    if (-not $env:KLIPIO_SIGN_THUMBPRINT) { Write-Host "Unsigned local build: $([IO.Path]::GetFileName($File))"; return }
    & (Join-Path $PSScriptRoot 'sign_windows_binary.ps1') -File $File
    if ($LASTEXITCODE) { throw 'Authenticode signing failed.' }
}
