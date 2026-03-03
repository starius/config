#!/bin/sh

# This script installs the Nix package manager on your system by
# downloading a binary distribution and running its installer script
# (which in turn creates and populates /nix).

{ # Prevent execution if this script was only partially downloaded
oops() {
    echo "$0:" "$@" >&2
    exit 1
}

umask 0022

tmpDir="$(mktemp -d -t nix-binary-tarball-unpack.XXXXXXXXXX || \
          oops "Can't create temporary directory for downloading the Nix binary tarball")"
cleanup() {
    rm -rf "$tmpDir"
}
trap cleanup EXIT INT QUIT TERM

require_util() {
    command -v "$1" > /dev/null 2>&1 ||
        oops "you do not have '$1' installed, which I need to $2"
}

case "$(uname -s).$(uname -m)" in
    Linux.x86_64)
        hash=5676b0887f1274e62edd175b6611af49aa8170c69c16877aa9bc6cebceb19855
        path=p7hsklhahf9l8igbijc4r74vgiaqnm8d/nix-2.34.0-x86_64-linux.tar.xz
        system=x86_64-linux
        ;;
    Linux.i?86)
        hash=34ff599a5e2c737deae1fc8dd33d5799ea5b226360d9224c0c3287ae031d7b69
        path=lfp03rz1frvxnhvimj2x724lsnw43war/nix-2.34.0-i686-linux.tar.xz
        system=i686-linux
        ;;
    Linux.aarch64)
        hash=cfddd4008b57a71464a16d5232cba79b1c76ae9dc81bbf71b4972b0118bc29c5
        path=9cwmhn5rqs62v6x8bqslrdz07g3f2ccf/nix-2.34.0-aarch64-linux.tar.xz
        system=aarch64-linux
        ;;
    Linux.armv6l)
        hash=7494434b4385d02f84fd9749dd0cf9988f0d6880ebcb24e356c8d4b99ee41d43
        path=d6ah835n855k4nz4q7lhq735nsis9lfl/nix-2.34.0-armv6l-linux.tar.xz
        system=armv6l-linux
        ;;
    Linux.armv7l)
        hash=050c7ac67e544bd2f6cdbc6c59381d842a952abceb2fca29f3a5448b47814a5c
        path=bbbxmm2xasj880xjd0m9zxxp6av6n2q3/nix-2.34.0-armv7l-linux.tar.xz
        system=armv7l-linux
        ;;
    Linux.riscv64)
        hash=479a2727760930b437f1cbbcc717ee3a9255062254a5e0e3171df2a0e84359e9
        path=30gmx4nw3fbqk27ks40vjzdy1xam7gyv/nix-2.34.0-riscv64-linux.tar.xz
        system=riscv64-linux
        ;;
    Darwin.x86_64)
        hash=d3d00cba2a309c6c8d12469916f1729221c74f6326f486c51d361f0c797d947f
        path=gb17z8rhf3qialb8pvcmf11qdspw7w0l/nix-2.34.0-x86_64-darwin.tar.xz
        system=x86_64-darwin
        ;;
    Darwin.arm64|Darwin.aarch64)
        hash=47cb78c9fdc7b630dbbb9a89869c8e8bcd8c9eb17be036fba18585120693a4c1
        path=1jhg8jbdv55r320rd59q0f69jwf2j84r/nix-2.34.0-aarch64-darwin.tar.xz
        system=aarch64-darwin
        ;;
    *) oops "sorry, there is no binary distribution of Nix for your platform";;
esac

# Use this command-line option to fetch the tarballs using nar-serve or Cachix
if [ "${1:-}" = "--tarball-url-prefix" ]; then
    if [ -z "${2:-}" ]; then
        oops "missing argument for --tarball-url-prefix"
    fi
    url=${2}/${path}
    shift 2
else
    url=https://releases.nixos.org/nix/nix-2.34.0/nix-2.34.0-$system.tar.xz
fi

tarball=$tmpDir/nix-2.34.0-$system.tar.xz

require_util tar "unpack the binary tarball"
if [ "$(uname -s)" != "Darwin" ]; then
    require_util xz "unpack the binary tarball"
fi

if command -v curl > /dev/null 2>&1; then
    fetch() { curl --fail -L "$1" -o "$2"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget "$1" -O "$2"; }
else
    oops "you don't have wget or curl installed, which I need to download the binary tarball"
fi

echo "downloading Nix 2.34.0 binary tarball for $system from '$url' to '$tmpDir'..."
fetch "$url" "$tarball" || oops "failed to download '$url'"

if command -v sha256sum > /dev/null 2>&1; then
    hash2="$(sha256sum -b "$tarball" | cut -c1-64)"
elif command -v shasum > /dev/null 2>&1; then
    hash2="$(shasum -a 256 -b "$tarball" | cut -c1-64)"
elif command -v openssl > /dev/null 2>&1; then
    hash2="$(openssl dgst -r -sha256 "$tarball" | cut -c1-64)"
else
    oops "cannot verify the SHA-256 hash of '$url'; you need one of 'shasum', 'sha256sum', or 'openssl'"
fi

if [ "$hash" != "$hash2" ]; then
    oops "SHA-256 hash mismatch in '$url'; expected $hash, got $hash2"
fi

unpack=$tmpDir/unpack
mkdir -p "$unpack"
tar -xJf "$tarball" -C "$unpack" || oops "failed to unpack '$url'"

script=$(echo "$unpack"/*/install)

[ -e "$script" ] || oops "installation script is missing from the binary tarball!"
export INVOKED_FROM_INSTALL_IN=1
"$script" "$@"

} # End of wrapping
