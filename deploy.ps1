# Everglow deploy script — builds React web bundle and deploys to Firebase.

Write-Host "Building React app..."
$allowedClientKeys = @('FCM_VAPID_KEY', 'SPOTIFY_CLIENT_ID')
if (Test-Path "assets/env.txt") {
  Get-Content "assets/env.txt" | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') {
      if ($allowedClientKeys -contains $matches[1]) {
        [Environment]::SetEnvironmentVariable("VITE_$($matches[1])", $matches[2], "Process")
      }
    }
  }
}

npm --prefix react run typecheck
if ($LASTEXITCODE -ne 0) { Write-Host "Typecheck failed"; exit 1 }

npm --prefix react run build
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

Write-Host "Deploying to Firebase..."
firebase deploy --only functions,hosting,firestore:rules,storage --force
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed"; exit 1 }

$ver = (Get-Content "react/package.json" -Raw | ConvertFrom-Json).version
$commitHash = (git rev-parse --short HEAD 2>$null)
if (-not $commitHash) { $commitHash = "unknown" }
Write-Host "Done. BUILD=$ver-$commitHash - users will get fresh cache."
