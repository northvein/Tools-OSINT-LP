#!/usr/bin/env bash
#
# setup-osint-laptop.sh
# Installs Google Chrome and LibreOffice on Ubuntu 26.04, then sets the
# OSINT homepage as the browser homepage / startup page for all users.
#
# Usage:
#   sudo ./setup-osint-laptop.sh [path/to/osint-homepage.html]
#
# If no path is given, osint-homepage.html is expected next to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOMEPAGE="${1:-$SCRIPT_DIR/osint-homepage.html}"

INSTALL_DIR="/opt/osint"
HOMEPAGE_PATH="$INSTALL_DIR/osint-homepage.html"
HOMEPAGE_URL="file://$HOMEPAGE_PATH"

CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
CHROME_POLICY_DIR="/etc/opt/chrome/policies/managed"
FIREFOX_POLICY_DIR="/etc/firefox/policies"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---- Pre-flight checks ------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this script with sudo: sudo $0"
[[ -f "$SRC_HOMEPAGE" ]] || die "Homepage file not found: $SRC_HOMEPAGE"

if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    die "This script targets Ubuntu (detected: ${ID:-unknown})."
  fi
  [[ "${VERSION_ID:-}" == "26.04" ]] || warn "Written for Ubuntu 26.04; detected ${VERSION_ID:-unknown}. Continuing."
fi

ARCH="$(dpkg --print-architecture)"
[[ "$ARCH" == "amd64" ]] || die "Google Chrome for Linux is only available for amd64 (detected: $ARCH)."

export DEBIAN_FRONTEND=noninteractive

# ---- Base packages ----------------------------------------------------------
log "Updating package lists"
apt-get update -y
apt-get install -y wget ca-certificates

# ---- Google Chrome ----------------------------------------------------------
if command -v google-chrome-stable >/dev/null 2>&1; then
  log "Google Chrome already installed: $(google-chrome-stable --version)"
else
  log "Downloading Google Chrome"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  wget -q --show-progress -O "$TMP_DIR/google-chrome.deb" "$CHROME_DEB_URL"

  log "Installing Google Chrome"
  # The package also adds Google's apt repository so Chrome updates with apt.
  apt-get install -y "$TMP_DIR/google-chrome.deb"
fi

# ---- LibreOffice ------------------------------------------------------------
log "Installing LibreOffice"
apt-get install -y libreoffice

# ---- Homepage file ----------------------------------------------------------
log "Installing homepage to $HOMEPAGE_PATH"
install -d -m 0755 "$INSTALL_DIR"
install -m 0644 "$SRC_HOMEPAGE" "$HOMEPAGE_PATH"

# ---- Chrome policy: homepage + startup page ---------------------------------
log "Setting Chrome homepage policy"
install -d -m 0755 "$CHROME_POLICY_DIR"
cat > "$CHROME_POLICY_DIR/osint-homepage.json" <<EOF
{
  "HomepageLocation": "$HOMEPAGE_URL",
  "HomepageIsNewTabPage": false,
  "ShowHomeButton": true,
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["$HOMEPAGE_URL"]
}
EOF
chmod 0644 "$CHROME_POLICY_DIR/osint-homepage.json"

# ---- Firefox policy (Ubuntu's default browser) ------------------------------
# The Firefox snap reads system policies from /etc/firefox/policies.
log "Setting Firefox homepage policy"
install -d -m 0755 "$FIREFOX_POLICY_DIR"
if [[ -f "$FIREFOX_POLICY_DIR/policies.json" ]]; then
  cp -a "$FIREFOX_POLICY_DIR/policies.json" "$FIREFOX_POLICY_DIR/policies.json.bak.$(date +%Y%m%d%H%M%S)"
  warn "Existing Firefox policies.json backed up and replaced."
fi
cat > "$FIREFOX_POLICY_DIR/policies.json" <<EOF
{
  "policies": {
    "Homepage": {
      "URL": "$HOMEPAGE_URL",
      "StartPage": "homepage",
      "Locked": false
    }
  }
}
EOF
chmod 0644 "$FIREFOX_POLICY_DIR/policies.json"

# ---- Make Chrome the default browser for the invoking user ------------------
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  log "Setting Google Chrome as default browser for $SUDO_USER"
  sudo -u "$SUDO_USER" xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null \
    || warn "Could not set default browser (run 'xdg-settings set default-web-browser google-chrome.desktop' from the desktop session)."
fi

# ---- Summary ----------------------------------------------------------------
log "Done"
echo "  Chrome:      $(google-chrome-stable --version 2>/dev/null || echo 'not found')"
echo "  LibreOffice: $(libreoffice --version 2>/dev/null | head -n1 || echo 'not found')"
echo "  Homepage:    $HOMEPAGE_URL"
echo
echo "Restart any open browsers. Verify Chrome picked up the policy at chrome://policy"
