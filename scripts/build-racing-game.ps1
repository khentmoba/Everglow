param(
  [string]$TargetDir = "..\build\web\racing"
)

Write-Host "Building racing game..." -ForegroundColor Cyan

$racingDir = Join-Path $PSScriptRoot "..\racing-game"
$distDir = Join-Path $racingDir "dist"

Push-Location $racingDir

# Build using npm via PATH
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "Build failed!" -ForegroundColor Red
  Pop-Location
  exit 1
}

# Copy to target
$target = Join-Path $PSScriptRoot $TargetDir
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -Recurse -Force "$distDir\*" $target

Pop-Location
Write-Host "Done! Copied to $target" -ForegroundColor Green
