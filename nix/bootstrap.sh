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
    qubes-core-agent-passwordless-root pipewire-qubes qubes-usb-proxy

echo "- Disabling RAM disk in /tmp..."
systemctl mask tmp.mount

# Enable typing in Unicode in bash.
echo "en_US.UTF-8 UTF-8" | tee /etc/locale.gen
locale-gen
localedef -i en_US -f UTF-8 en_US.UTF-8
update-locale LANG=en_US.utf8

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
    ./nix-install.sh --daemon --yes
fi

# Enable Flakes globally.
mkdir -p /etc/nix
if ! grep -q "experimental-features" "$NIX_CONF_FILE"; then
    echo "experimental-features = nix-command flakes" | tee -a "$NIX_CONF_FILE"
    echo "trusted-users = root user" | tee -a "$NIX_CONF_FILE"
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

# Make sure bash-completion is loaded in all shells.
if ! grep -q "/nix/var/nix/profiles/default/etc/profile.d/bash_completion.sh" "$BASHRC_GLOBAL"; then
    echo '
# Enable programmable completion features in non-login shells.
if [ -f /nix/var/nix/profiles/default/etc/profile.d/bash_completion.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/bash_completion.sh
fi
' >> "$BASHRC_GLOBAL"
fi

echo "OK Nix daemon installed."

# Switch to 'user' to build Flake.
echo "- Switching to user 'user' to build Nix Flake..."
# Exclude manually built packages from checksum matching.
EXCLUDE_PKG_REGEX='-codex-'
su - user <<EOF
set -euo pipefail

# Load Nix environment.
. /etc/profile.d/nix.sh

# Go to the flake directory (where bootstrap.sh is located).
cd $SCRIPT_DIR

# Build programs and configs in / from Flake.
nix build .#fake-root --out-link result-fake-root
nix build .#apps --out-link result-apps --max-jobs 1 --cores 1

echo "OK Flake build complete."

echo "- Comparing binaries with expected values..."
# Make a list of paths of all the packages of apps. Sort by package name.
nix-store --query --requisites ./result-apps | sort -k 1.45 > paths.txt
# Drop excluded packages before hashing.
awk -v pat="$EXCLUDE_PKG_REGEX" '\$0 !~ pat' paths.txt > paths.filtered.txt
# Calculate all the hashes of paths (of outputs, not inputs).
paste -d '\t' <(cat paths.filtered.txt) <(xargs nix-store --query --hash < paths.filtered.txt) > got-binary-hashes.txt
# Filter expected values to match excluded packages.
awk -v pat="$EXCLUDE_PKG_REGEX" '\$0 !~ pat' want-binary-hashes.txt > want-binary-hashes.filtered.txt
# Compare with the expected values.
if ! cmp "got-binary-hashes.txt" "want-binary-hashes.filtered.txt"; then
    echo "!!! Mismatch of binary files in packages. Aborting."
    exit 1
fi
echo "OK Binary files are correct!"

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

# Now clean the store.
echo "- Running nix-collect-garbage -d ..."
/nix/var/nix/profiles/default/bin/nix-collect-garbage -d
echo "- Running nix store optimise ..."
/nix/var/nix/profiles/default/bin/nix store optimise

echo "OK System-wide Nix environment setup complete."
