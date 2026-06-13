<#
.SYNOPSIS
    Sync the bundled AssaultCube WebAssembly prebuilt files from
    scripts/ac_wasm/ into web/ac_wasm/ for deployment.

.DESCRIPTION
    The community port (https://github.com/Gibgoyt/assaultCubeWasm) ships
    prebuilt ac_client_wasm.{wasm,js,data,html} artifacts. We keep the
    upstream clone in scripts/ac_wasm/ (gitignored) and copy the four
    prebuilt files into web/ac_wasm/ so flutter build web bundles them.

.PARAMETER Source
    Path to the upstream clone. Defaults to .\scripts\ac_wasm relative
    to the repo root.

.PARAMETER Destination
    Path to copy into. Defaults to .\web\ac_wasm relative to the repo
    root.

.EXAMPLE
    pwsh ./scripts/copy_ac_wasm.ps1
#>

[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot 'ac_wasm'),
    [string]$Destination = (Join-Path (Split-Path $PSScriptRoot -Parent) 'web\ac_wasm')
)

$ErrorActionPreference = 'Stop'

$files = @(
    'ac_client_wasm.wasm',
    'ac_client_wasm.js',
    'ac_client_wasm.data',
    'ac_client_wasm.html'
)

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Error "Source not found: $Source`nClone the upstream first:`n  git clone --depth 1 https://github.com/Gibgoyt/assaultCubeWasm.git $Source"
    exit 1
}

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$total = 0
foreach ($f in $files) {
    $src = Join-Path $Source $f
    $dst = Join-Path $Destination $f
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Error "Missing upstream file: $src"
        exit 1
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $size = (Get-Item -LiteralPath $dst).Length
    $total += $size
    Write-Host ("  copied {0,-26} {1,12:N0} bytes" -f $f, $size)
}

$mb = [math]::Round($total / 1MB, 1)
Write-Host ""
Write-Host "Done. $mb MB copied to $Destination" -ForegroundColor Green
Write-Host "Next: flutter build web (or commit + push to trigger deploy)"
