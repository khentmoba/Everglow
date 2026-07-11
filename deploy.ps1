$pubspec = Get-Content "pubspec.yaml" -Raw
$versionMatch = [regex]::Match($pubspec, 'version:\s*(\S+)')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "0.0.0+0" }

$commitHash = (git rev-parse --short HEAD 2>$null)
if (-not $commitHash) { $commitHash = "unknown" }

$buildConst = "$version-$commitHash"

$swContent = @"
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', () => {
  self.registration.unregister();
});
"@

Set-Content -Path "web\sw.js" -Value $swContent -NoNewline
Write-Host "sw.js written with BUILD = $buildConst"

Write-Host "Running flutter build web..."
flutter build web
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

Write-Host "Deploying to Firebase..."
firebase deploy --only functions,hosting,firestore:rules
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed"; exit 1 }

Write-Host "Done. BUILD=$buildConst - users will get fresh cache."
