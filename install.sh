#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
#  Everglow — one-command setup script
#  Checks prerequisites, installs dependencies, and
#  shows the adblock recommendation for Cinema/Anime.
# ──────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

step()  { echo -e "\n${CYAN}==>${NC} $1"; }
ok()    { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[!]${NC} $1"; }

clear 2>/dev/null || true

# ──────────────────────────────────────────────
#  Adblock recommendation  (mirrors AdblockerGate)
# ──────────────────────────────────────────────
echo -e "${MAGENTA}"
cat << 'EOF'

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
  │  • Samsung Internet → Adblock Plus       │
  │  • Safari on iOS → Adblock Plus          │
  │  • Kiwi Browser (Android) → uBlock       │
  │  • AdGuard (system-wide, any browser)    │
  └──────────────────────────────────────────┘

EOF
echo -e "${NC}"

read -rp "Press Enter to continue with installation (or Ctrl+C to cancel) "

# ──────────────────────────────────────────────
#  Step 1 — Prerequisites
# ──────────────────────────────────────────────
step "Checking prerequisites"

HAS_FLUTTER=false
if command -v flutter &>/dev/null; then
  HAS_FLUTTER=true
  ok "Flutter SDK found ($(flutter --version 2>&1 | head -1))"
else
  warn "Flutter SDK is not installed or not on PATH."
  warn "Install it from: https://docs.flutter.dev/get-started/install"
  read -rp "Continue anyway? (y/N) " ans
  [[ "$ans" != "y" ]] && { echo "Aborted."; exit 1; }
fi

HAS_FIREBASE=false
if command -v firebase &>/dev/null; then
  HAS_FIREBASE=true
  ok "Firebase CLI v$(firebase --version)"
else
  warn "Firebase CLI not found. Install with: npm install -g firebase-tools"
fi

# ──────────────────────────────────────────────
#  Step 2 — Environment file
# ──────────────────────────────────────────────
step "Environment file"

DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$DIR/assets/env.txt"

if [ ! -f "$ENV_FILE" ]; then
  warn "assets/env.txt is missing."
  warn "Create it with your Firebase config secrets before running."
  echo "  Expected format (ask the project owner for values):"
  echo "    TMDB_API_KEY=your_key"
  echo "    LASTFM_API_KEY=your_key"
  echo "    OPEN_WEATHER_API_KEY=your_key"
  read -rp "Create a placeholder now? (y/N) " ans
  if [ "$ans" = "y" ]; then
    cat > "$ENV_FILE" << 'EOF'
TMDB_API_KEY=YOUR_TMDB_API_KEY
LASTFM_API_KEY=YOUR_LASTFM_API_KEY
OPEN_WEATHER_API_KEY=YOUR_OPEN_WEATHER_API_KEY
EOF
    ok "Placeholder created — edit assets/env.txt with real keys"
  fi
else
  ok "assets/env.txt found"
fi

# ──────────────────────────────────────────────
#  Step 3 — Flutter dependencies
# ──────────────────────────────────────────────
step "Installing Flutter dependencies"
flutter pub get
ok "Dependencies installed"

# ──────────────────────────────────────────────
#  Step 4 — Firebase config check
# ──────────────────────────────────────────────
step "Firebase configuration"
if [ -f "$DIR/lib/firebase_options.dart" ]; then
  ok "firebase_options.dart found"
else
  warn "firebase_options.dart missing — run: flutterfire configure"
fi

# ──────────────────────────────────────────────
#  Done
# ──────────────────────────────────────────────
step "Installation complete!"

echo -e "${GREEN}"
cat << 'EOF'
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

EOF
echo -e "${NC}"
