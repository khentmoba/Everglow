$pubspec = Get-Content "pubspec.yaml" -Raw
$versionMatch = [regex]::Match($pubspec, 'version:\s*(\S+)')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "0.0.0+0" }

$commitHash = (git rev-parse --short HEAD 2>$null)
if (-not $commitHash) { $commitHash = "unknown" }

$buildConst = "$version-$commitHash"

$swContent = @"
const BUILD = '$buildConst';
let isUpdate = false;

self.addEventListener('install', (event) => {
  isUpdate = !!self.registration.active;
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(keys.map((key) => caches.delete(key)));
    }).then(() => {
      return self.clients.claim();
    }).then(() => {
      if (isUpdate) {
        return self.clients.matchAll().then((clients) => {
          clients.forEach((client) => {
            client.postMessage({ type: 'NEW_VERSION', version: '$buildConst' });
          });
        });
      }
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
"@

Set-Content -Path "web\sw.js" -Value $swContent -NoNewline
Write-Host "sw.js written with BUILD = $buildConst"

Write-Host "Running flutter build web..."
flutter build web
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

Write-Host "Deploying to Firebase..."
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed"; exit 1 }

Write-Host "Done. BUILD=$buildConst — users will get fresh cache."
