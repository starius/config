#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [--server]

  --server   Install the lightweight Debian server profile
             (CLI and development tools only, no GUI, no Qubes setup)
EOF
}

PROFILE="qubes"
for arg in "$@"; do
    case "$arg" in
        --server)
            PROFILE="server"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

SERVER_MODE=false
FAKE_ROOT_ATTR="fake-root"
APPS_ATTR="apps"
if [ "$PROFILE" = "server" ]; then
    SERVER_MODE=true
    FAKE_ROOT_ATTR="fake-root-server"
    APPS_ATTR="apps-server"
fi

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

choose_build_user() {
    local script_owner

    script_owner="$(stat -c '%U' "$SCRIPT_DIR")"
    if [ "$script_owner" != "UNKNOWN" ] && [ "$script_owner" != "root" ] \
        && id -u "$script_owner" >/dev/null 2>&1 \
        && sudo -u "$script_owner" test -w "$SCRIPT_DIR"; then
        printf '%s\n' "$script_owner"
        return
    fi

    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] \
        && id -u "$SUDO_USER" >/dev/null 2>&1 \
        && sudo -u "$SUDO_USER" test -w "$SCRIPT_DIR"; then
        printf '%s\n' "$SUDO_USER"
        return
    fi

    if id -u user >/dev/null 2>&1 && sudo -u user test -w "$SCRIPT_DIR"; then
        printf '%s\n' "user"
        return
    fi

    printf '%s\n' "root"
}

ensure_nix_conf_key() {
    local key="$1"
    local value="$2"

    if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$NIX_CONF_FILE"; then
        sed -i "s|^[[:space:]]*$key[[:space:]]*=.*$|$key = $value|" "$NIX_CONF_FILE"
    else
        echo "$key = $value" >> "$NIX_CONF_FILE"
    fi
}

ensure_trusted_user() {
    local account="$1"
    local current

    if grep -Eq "^[[:space:]]*trusted-users[[:space:]]*=" "$NIX_CONF_FILE"; then
        current="$(sed -n 's/^[[:space:]]*trusted-users[[:space:]]*=[[:space:]]*//p' "$NIX_CONF_FILE" | tail -n 1)"
        case " $current " in
            *" $account "*)
                return
                ;;
        esac
        current="$(printf '%s %s\n' "$current" "$account" | awk '{$1=$1; print}')"
        sed -i "s|^[[:space:]]*trusted-users[[:space:]]*=.*$|trusted-users = $current|" "$NIX_CONF_FILE"
    else
        echo "trusted-users = $account" >> "$NIX_CONF_FILE"
    fi
}

COMMON_APT_PACKAGES=(
    sudo
    curl
    xz-utils
    locales
)

QUBES_APT_PACKAGES=(
    qubes-core-agent-networking
    qubes-core-agent-passwordless-root
    pipewire-qubes
    qubes-usb-proxy
)

APT_PACKAGES=("${COMMON_APT_PACKAGES[@]}")
if [ "$SERVER_MODE" = false ]; then
    APT_PACKAGES+=("${QUBES_APT_PACKAGES[@]}")
fi

echo "- Installing required system packages for profile '$PROFILE'..."
apt update
apt install -y "${APT_PACKAGES[@]}"

if [ "$SERVER_MODE" = false ]; then
    echo "- Disabling RAM disk in /tmp..."
    systemctl mask tmp.mount
fi

# Enable typing in Unicode in bash.
echo "en_US.UTF-8 UTF-8" | tee /etc/locale.gen
locale-gen
localedef -i en_US -f UTF-8 en_US.UTF-8
update-locale LANG=en_US.utf8

BUILD_USER="$(choose_build_user)"
echo "- Using build user '$BUILD_USER'..."

# Make sure the build user can create "result-*" symlinks in the flake directory.
if [ "$BUILD_USER" != "root" ] && ! sudo -u "$BUILD_USER" test -w "$SCRIPT_DIR"; then
    echo "!!! The directory $SCRIPT_DIR is not writable by user '$BUILD_USER'. Aborting."
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
touch "$NIX_CONF_FILE"
ensure_nix_conf_key "experimental-features" "nix-command flakes"
ensure_trusted_user "root"
if [ "$BUILD_USER" != "root" ]; then
    ensure_trusted_user "$BUILD_USER"
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

# Switch to the selected user to build the Flake.
echo "- Building Nix flake profile '$PROFILE' as '$BUILD_USER'..."
# Exclude manually built packages from checksum matching.
EXCLUDE_PKG_REGEX='-codex-'
ALLOW_MISSING_BINARY_HASHES="$SERVER_MODE"
su - "$BUILD_USER" -s /bin/bash <<EOF
set -euo pipefail

# Load Nix environment.
. /etc/profile.d/nix.sh

# Go to the flake directory (where bootstrap.sh is located).
cd "$SCRIPT_DIR"

# Build programs and configs in / from Flake.
nix build ".#$FAKE_ROOT_ATTR" --out-link result-fake-root
nix build ".#$APPS_ATTR" --out-link result-apps --max-jobs 1 --cores 1

echo "OK Flake build complete."

echo "- Comparing binaries with expected values..."
APPS_STORE_PATH=\$(readlink -f ./result-apps)
# Make a list of paths of all the packages of apps. Sort by package name.
nix-store --query --requisites "\$APPS_STORE_PATH" | sort -k 1.45 > paths.txt
# Drop excluded packages before hashing.
awk -v pat="$EXCLUDE_PKG_REGEX" '\$0 !~ pat' paths.txt > paths.filtered.txt
if [ "$ALLOW_MISSING_BINARY_HASHES" = true ]; then
    # The server profile has a different top-level buildEnv output, so compare
    # only its realized package closure against the full manifest.
    grep -Fvx "\$APPS_STORE_PATH" paths.filtered.txt > paths.profile.txt || true
    mv paths.profile.txt paths.filtered.txt
fi
# Calculate all the hashes of paths (of outputs, not inputs).
paste -d '\t' <(cat paths.filtered.txt) <(xargs nix-store --query --hash < paths.filtered.txt) > got-binary-hashes.txt
# Filter expected values to match excluded packages.
awk -v pat="$EXCLUDE_PKG_REGEX" '\$0 !~ pat' want-binary-hashes.txt > want-binary-hashes.filtered.txt
EXPECTED_HASHES_FILE="want-binary-hashes.filtered.txt"
if [ "$ALLOW_MISSING_BINARY_HASHES" = true ]; then
    EXPECTED_HASHES_FILE="want-binary-hashes.expected.txt"
    awk 'BEGIN { FS = OFS = "\t" } NR == FNR { wanted[\$1] = 1; next } \$1 in wanted' \
        <(cut -f1 got-binary-hashes.txt) \
        want-binary-hashes.filtered.txt > "\$EXPECTED_HASHES_FILE"
    if [ "\$(wc -l < "\$EXPECTED_HASHES_FILE")" -ne "\$(wc -l < got-binary-hashes.txt)" ]; then
        echo "!!! Some built packages are not present in want-binary-hashes.txt. Aborting."
        echo "Unexpected package paths:"
        comm -23 <(cut -f1 got-binary-hashes.txt) <(cut -f1 "\$EXPECTED_HASHES_FILE") || true
        exit 1
    fi
fi
# Compare with the expected values.
if ! cmp "got-binary-hashes.txt" "\$EXPECTED_HASHES_FILE"; then
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

# Make pinned nixpkgs the default flake registry entry using the locked GitHub
# flakeref from flake.lock.
JQ_BIN="/nix/var/nix/profiles/default/bin/jq"
if [ ! -x "$JQ_BIN" ]; then
    echo "!!! jq is missing from /nix/var/nix/profiles/default/bin. Aborting."
    exit 1
fi
NIXPKGS_FLAKE_REF="$(
    "$JQ_BIN" -er '
        .nodes.nixpkgs.locked as $locked
        | if $locked.type != "github" then
            error("expected flake.lock nodes.nixpkgs.locked.type to be github")
          else
            "github:\($locked.owner)/\($locked.repo)/\($locked.rev)"
          end
    ' "$SCRIPT_DIR/flake.lock"
)"
/nix/var/nix/profiles/default/bin/nix registry add \
    --registry /etc/nix/registry.json \
    nixpkgs "$NIXPKGS_FLAKE_REF"
echo "- Pinned nixpkgs flake registry: nixpkgs -> $NIXPKGS_FLAKE_REF"

# Now clean the store.
echo "- Running nix-collect-garbage -d ..."
/nix/var/nix/profiles/default/bin/nix-collect-garbage -d
echo "- Running nix store optimise ..."
/nix/var/nix/profiles/default/bin/nix store optimise

echo "OK System-wide Nix environment setup complete."
