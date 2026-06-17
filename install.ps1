#Requires -Version 5.1
<#
.SYNOPSIS
  Everglow — one-command setup for the private digital relationship scrapbook.
.DESCRIPTION
  Checks prerequisites, installs dependencies, and shows the adblock
  recommendation for Cinema / Anime streaming features.
#>

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Everglow Installer'

function Write-Step($s) { Write-Host "`n==> $s" -ForegroundColor Cyan }
function Write-Ok($s)   { Write-Host "  [OK] $s" -ForegroundColor Green }
function Write-Warn($s) { Write-Host "  [!] $s" -ForegroundColor Yellow }

Clear-Host

# ──────────────────────────────────────────────
#  Adblock recommendation  (mirrors AdblockerGate)
# ──────────────────────────────────────────────
Write-Host @"

  ╔══════════════════════════════════════════════╗
  ║          Adblocker Recommended               ║
  ╚══════════════════════════════════════════════╝

  Streaming sources may show intrusive ads.
  Installing an adblocker gives you a cleaner,
  faster experience.

  ┌──────────────────────────────────────────┐
  │  uBlock Origin  (Desktop)                │
  │  Free, open-source, low memory           │
  │                                          │
  │  Works on Chrome, Firefox, Edge, Brave,  │
  │  and Opera. Blocks ads, trackers, and    │
  │  malicious domains — no configuration.   │
  └──────────────────────────────────────────┘

  Install:  https://ublockorigin.com

  ┌──────────────────────────────────────────┐
  │  Mobile Options                          │
  │                                          │
  │  • Firefox for Android → install uBlock  │
  │    https://mzl.la/3RTVF2p               │
  │  • Samsung Internet → Adblock Plus       │
  │    https://adblockplus.org               │
  │  • Safari on iOS → Adblock Plus          │
  │    https://adblockplus.org               │
  │  • Kiwi Browser (Android) → uBlock       │
  │    https://bit.ly/3RTVF2p               │
  │  • AdGuard (system-wide, any browser)    │
  │    https://adguard.com                   │
  └──────────────────────────────────────────┘

"@ -ForegroundColor Magenta

$choice = Read-Host "Press Enter to continue with installation (or Ctrl+C to cancel)"

# ──────────────────────────────────────────────
#  Step 1 — Prerequisites
# ──────────────────────────────────────────────
Write-Step "Checking prerequisites"

$hasFlutter = $false
try {
  $fv = & flutter --version 2>&1 | Select-String -Pattern '^Flutter'
  if ($fv) { $hasFlutter = $true; Write-Ok "Flutter SDK found" }
} catch {}

if (-not $hasFlutter) {
  Write-Warn "Flutter SDK is not installed or not on PATH."
  Write-Warn "Install it from: https://docs.flutter.dev/get-started/install"
  $install = Read-Host "Continue anyway? (y/N)"
  if ($install -ne 'y') { Write-Host "Aborted."; return }
}

$hasFirebase = $false
try {
  $fb = & firebase --version 2>&1
  if ($fb) { $hasFirebase = $true; Write-Ok "Firebase CLI v$fb" }
} catch {}

if (-not $hasFirebase) {
  Write-Warn "Firebase CLI not found. Install with: npm install -g firebase-tools"
}

# ──────────────────────────────────────────────
#  Step 2 — Environment file
# ──────────────────────────────────────────────
Write-Step "Environment file"

$envFile = Join-Path $PSScriptRoot 'assets\env.txt'
if (-not (Test-Path $envFile)) {
  Write-Warn "assets/env.txt is missing."
  Write-Warn "Create it with your Firebase config secrets before running."
  Write-Host "  Expected format (ask the project owner for values):"
  Write-Host "    TMDB_API_KEY=your_key"
  Write-Host "    LASTFM_API_KEY=your_key"
  Write-Host "    OPEN_WEATHER_API_KEY=your_key"
  $create = Read-Host "Create a placeholder now? (y/N)"
  if ($create -eq 'y') {
    @"
TMDB_API_KEY=YOUR_TMDB_API_KEY
LASTFM_API_KEY=YOUR_LASTFM_API_KEY
OPEN_WEATHER_API_KEY=YOUR_OPEN_WEATHER_API_KEY
"@ | Out-File -Encoding utf8 $envFile
    Write-Ok "Placeholder created — edit assets/env.txt with real keys"
  }
} else {
  Write-Ok "assets/env.txt found"
}

# ──────────────────────────────────────────────
#  Step 3 — Flutter dependencies
# ──────────────────────────────────────────────
Write-Step "Installing Flutter dependencies"
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
Write-Ok "Dependencies installed"

# ──────────────────────────────────────────────
#  Step 4 — Firebase config check
# ──────────────────────────────────────────────
Write-Step "Firebase configuration"
$fbOpt = Join-Path $PSScriptRoot 'lib\firebase_options.dart'
if (Test-Path $fbOpt) {
  Write-Ok "firebase_options.dart found"
} else {
  Write-Warn "firebase_options.dart missing — run: flutterfire configure"
}

# ──────────────────────────────────────────────
#  Done
# ──────────────────────────────────────────────
Write-Step "Installation complete!"

Write-Host @"
  ─────────────────────────────────────────────
  Start developing:

      flutter run -d chrome

  Build for production:

      flutter build web --release
      firebase deploy --only hosting

  ─────────────────────────────────────────────

  Don't forget to install an adblocker (see above)
  for the best Cinema & Anime experience on desktop
  and mobile!

"@ -ForegroundColor Green
