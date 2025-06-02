#!/bin/bash
set -euo pipefail

# Root check.
if [ "$(id -u)" -ne 0 ]; then
    echo "!!! This script must be run as root. Aborting."
    exit 1
fi

trap 'echo "!!! Error occurred on line $LINENO. Aborting."; exit 1;' ERR

# Dynamically find where the script is.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths based on script location.
NIX_CONF_FILE="/etc/nix/nix.conf"
BASHRC_GLOBAL="/etc/bash.bashrc"
PROFILED_NIX="/etc/profile.d/99-qubes-nix.sh"

echo "- Installing required system packages..."
apt update
apt install -y sudo curl qubes-core-agent-networking xz-utils \
    qubes-core-agent-passwordless-root

# Make sure that the current directory is writable by "user", othwerwise they
# will fail to create "result-*" symlinks in "nix build" steps.
if ! sudo -u user test -w "$SCRIPT_DIR"; then
    echo "!!! The directory $SCRIPT_DIR is not writable by user 'user'. Aborting."
    exit 1
fi

echo "- Installing Nix multi-user daemon (if not installed)..."
if [ ! -d "/nix/store" ]; then
    export USER=root
    export NIX_INSTALLER_NO_MODIFY_PROFILE=1
    sh <(curl -L https://nixos.org/nix/install) --daemon --yes
fi

# Enable Flakes globally.
mkdir -p /etc/nix
if ! grep -q "experimental-features" "$NIX_CONF_FILE"; then
    echo "experimental-features = nix-command flakes" | tee -a "$NIX_CONF_FILE"
fi

# Make sure Nix is loaded in all shells.
if ! grep -q "/etc/profile.d/nix.sh" "$BASHRC_GLOBAL"; then
    echo '
# Nix support for non-login shells.
if [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi
' >> "$BASHRC_GLOBAL"
fi

echo "OK Nix daemon installed."

# Switch to 'user' to build Flake.
echo "- Switching to user 'user' to build Nix Flake..."
su - user <<EOF
set -euo pipefail

# Load Nix environment.
. /etc/profile.d/nix.sh

# Go to the flake directory (where bootstrap.sh is located).
cd $SCRIPT_DIR

# Build programs and configs in / from Flake.
nix build .#fake-root --out-link result-fake-root
nix build .#apps --out-link result-apps

echo "OK Flake build complete."
EOF

# Get the path to the Nix-built rsync.
RSYNC_BIN="$SCRIPT_DIR/result-apps/bin/rsync"

# Now sync the built fakeRoot to / .
FAKE_ROOT=$(readlink -f "$SCRIPT_DIR/result-fake-root")
echo "- Syncing config files to / using Nix rsync ..."
"$RSYNC_BIN" -aHAX "$FAKE_ROOT"/ /

# Register apps to system profile.
APPS_DIR=$(readlink -f "$SCRIPT_DIR/result-apps")
/nix/var/nix/profiles/default/bin/nix-env \
        --profile /nix/var/nix/profiles/default --set "$APPS_DIR"

echo "OK System-wide Nix environment setup complete."
