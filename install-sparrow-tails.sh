#!/bin/bash
# Sparrow Wallet installer for Tails (automates sections 2, 4 and 5 of the guide).
#
# Always downloads the LATEST version published on the official GitHub repo
# (never pins a version number), verifies the developer's PGP key fingerprint
# and signature (Craig Raw) and the file's SHA-256 checksum before installing
# anything. The app binaries and the wallet's persistent data live in
# separate directories, so re-running this script to upgrade never touches
# existing wallet data.
#
# Prerequisites (done manually before running this script):
#   - Administration Password enabled on the Tails welcome screen
#     (required for the sudo commands below).
#   - Persistent Storage with "Persistent Folder" and "Dotfiles" enabled.
#
# Usage:
#   ./install-sparrow-tails.sh

set -euo pipefail

if [ -t 1 ]; then
  BOLD="\033[1m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

TOTAL_STEPS=10
step_num=0
step() {
  step_num=$((step_num + 1))
  echo
  echo -e "${BOLD}${CYAN}[$step_num/$TOTAL_STEPS] $1${RESET}"
}

# Prints a green confirmation and waits for the user to acknowledge it
# before moving on. Reserved for security-critical checkpoints (key
# fingerprint, PGP signature, checksum) so those are actually reviewed
# rather than flying by with the rest of the output.
ok() {
  echo -e "${GREEN}${BOLD}OK:${RESET} ${GREEN}$1${RESET}"
  read -r -p "$(echo -e "${YELLOW}Press Enter to continue...${RESET}")" _
}

# Prints a green confirmation without pausing, for non-critical steps.
info() {
  echo -e "${GREEN}${BOLD}OK:${RESET} ${GREEN}$1${RESET}"
}

err() {
  echo -e "${RED}${BOLD}Error:${RESET} ${RED}$1${RESET}" >&2
  [ -n "${2:-}" ] && echo "$2" >&2
}

REPO="sparrowwallet/sparrow"
DOWNLOADS_DIR="$HOME/Downloads"
SW_DIR="$HOME/Persistent/SW"
APP_DIR="$SW_DIR/Sparrow"
DATA_DIR="$SW_DIR/data"
DOTFILES_APPS_DIR="/live/persistence/TailsData_unlocked/dotfiles/.local/share/applications"
DESKTOP_FILE="$DOTFILES_APPS_DIR/Sparrow.desktop"
DEVELOPER_KEY_URL="https://keybase.io/craigraw/pgp_keys.asc"
# Craig Raw's official Sparrow Wallet signing key, as published on
# https://sparrowwallet.com/download/ - pinned here so a compromised or
# spoofed key download can never pass verification.
EXPECTED_FINGERPRINT="D4D0D3202FC06849A257B38DE94618334C674B40"

cat <<'BANNER'
Sparrow Wallet installer for Tails
-----------------------------------
This script will:
  1. Look up the latest Sparrow release on GitHub
  2. Download the release files
  3. Verify the signing key's fingerprint, the PGP signature and the
     SHA-256 checksum
  4. Install Sparrow's app files under ~/Persistent/SW/Sparrow
     (wallet data stays separate, in ~/Persistent/SW/data)
  5. Add Sparrow to the Tails application menu

Nothing is installed if any verification step fails, and existing wallet
data is never touched, even when reinstalling or upgrading.
BANNER

mkdir -p "$DOWNLOADS_DIR"
cd "$DOWNLOADS_DIR"

step "Looking up the latest release published at github.com/$REPO"
if ! API_RESPONSE="$(curl -fsSL --retry 3 --retry-delay 5 --retry-connrefused "https://api.github.com/repos/$REPO/releases/latest")"; then
  err "could not reach the GitHub API (network/Tor may be unstable)." "Please check your connection and try again."
  exit 1
fi

if echo "$API_RESPONSE" | grep -qi '"message": *"API rate limit exceeded'; then
  err "GitHub API rate limit exceeded (common on shared Tor exit nodes)." "Please wait a while before trying again."
  exit 1
fi

VERSION="$(echo "$API_RESPONSE" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
if [ -z "$VERSION" ]; then
  err "could not determine the latest version."
  exit 1
fi
info "Latest version available: $VERSION"

TARBALL="sparrowwallet-${VERSION}-x86_64.tar.gz"
MANIFEST="sparrow-${VERSION}-manifest.txt"
MANIFEST_SIG="${MANIFEST}.asc"
BASE_URL="https://github.com/$REPO/releases/download/${VERSION}"

step "Downloading $TARBALL, $MANIFEST and $MANIFEST_SIG into $DOWNLOADS_DIR"
curl -fLO "$BASE_URL/$TARBALL"
curl -fLO "$BASE_URL/$MANIFEST"
curl -fLO "$BASE_URL/$MANIFEST_SIG"
info "Download complete."

step "Importing the PGP key of Craig Raw (Sparrow's developer) and pinning its fingerprint"
curl -fsSL "$DEVELOPER_KEY_URL" | gpg --import
IMPORTED_FINGERPRINTS="$(gpg --with-colons --fingerprint | awk -F: '/^fpr:/ {print $10}')"
if ! echo "$IMPORTED_FINGERPRINTS" | grep -q "$EXPECTED_FINGERPRINT"; then
  err "imported PGP key does not match Sparrow's known signing fingerprint ($EXPECTED_FINGERPRINT). Do not proceed."
  exit 1
fi
ok "Fingerprint OK: matches Sparrow's official signing key."

step "Verifying the manifest's PGP signature"
if ! gpg --verify "$MANIFEST_SIG" "$MANIFEST"; then
  err "invalid PGP signature. Do not proceed with this install."
  exit 1
fi
ok "Signature OK: the manifest was signed by the key above."

step "Verifying the downloaded file's SHA-256 checksum against the signed manifest"
if ! sha256sum --check "$MANIFEST" --ignore-missing 2>/dev/null | grep -Fqx "${TARBALL}: OK"; then
  err "checksum mismatch for $TARBALL. Do not proceed with this install."
  exit 1
fi
ok "Checksum OK. All checks passed: the downloaded file is authentic and untampered."

step "Preparing persistent folders in $SW_DIR"
mkdir -p "$DATA_DIR"
if [ -d "$APP_DIR" ]; then
  echo "Removing the previous app installation at $APP_DIR (wallet data in $DATA_DIR is untouched)."
  rm -rf "$APP_DIR"
fi
mkdir -p "$APP_DIR"

step "Moving $TARBALL to $SW_DIR and extracting Sparrow into $APP_DIR"
mv "$TARBALL" "$SW_DIR/"
rm -f "$MANIFEST" "$MANIFEST_SIG"
tar -xzf "$SW_DIR/$TARBALL" -C "$APP_DIR" --strip-components=1
info "Extracted bin/ and lib/ under $APP_DIR"

step "Test-running Sparrow to confirm the persistent data directory works"
echo "Close the Sparrow window when you're done checking it opens correctly."
"$APP_DIR/bin/Sparrow" -d "$DATA_DIR"
info "Sparrow closed. Test run complete."

step "Adding Sparrow to the Tails application menu"
echo "Writing $DESKTOP_FILE so the shortcut survives reboots."
mkdir -p "$DOTFILES_APPS_DIR"
tee "$DESKTOP_FILE" > /dev/null <<EOF
[Desktop Entry]
Name=Sparrow
Comment=Sparrow
Exec=$APP_DIR/bin/Sparrow -d $DATA_DIR %U
Icon=$APP_DIR/lib/Sparrow.png
Terminal=false
Type=Application
Categories=Finance;Network;
MimeType=application/psbt;application/bitcoin-transaction;x-scheme-handler/bitcoin;x-scheme-handler/auth47;x-scheme-handler/lightning
EOF
info "Application menu entry written."

echo
echo -e "${GREEN}${BOLD}Done! Sparrow $VERSION is installed.${RESET}"
echo "Sparrow will only appear in the application menu after a reboot"
echo "(that's how Tails' Dotfiles persistence feature works)."
echo
read -r -p "Reboot Tails now? This closes ALL open windows and unsaved work. [y/N] " reboot_answer
case "$reboot_answer" in
  [yY][eE][sS]|[yY])
    echo "Rebooting..."
    sudo reboot
    ;;
  *)
    echo "Not rebooting. Remember to restart Tails before Sparrow shows up in the menu."
    echo "After rebooting, open Sparrow, go to Preferences -> Server and set the Tor proxy to 127.0.0.1:9050."
    ;;
esac
