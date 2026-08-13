# Everglow deploy script — builds and deploys to Firebase.
# Service worker generation is handled by dart tool/generate_sw.dart.

Write-Host "Generating cache-busting service worker..."
dart tool/generate_sw.dart
if ($LASTEXITCODE -ne 0) { Write-Host "SW generation failed"; exit 1 }

Write-Host "Running flutter build web..."
$dartDefines = @()
if (Test-Path "assets/env.txt") {
  Get-Content "assets/env.txt" | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') {
      $dartDefines += "--dart-define=$($matches[1])=$($matches[2])"
    }
  }
}
flutter build web @dartDefines
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

Write-Host "Deploying to Firebase..."
firebase deploy --only functions,hosting,firestore:rules,storage
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed"; exit 1 }

# Read version info for the final message
$pubspec = Get-Content "pubspec.yaml" -Raw
$versionMatch = [regex]::Match($pubspec, 'version:\s*(\S+)')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "0.0.0+0" }
$commitHash = (git rev-parse --short HEAD 2>$null)
if (-not $commitHash) { $commitHash = "unknown" }
Write-Host "Done. BUILD=$version-$commitHash - users will get fresh cache."
