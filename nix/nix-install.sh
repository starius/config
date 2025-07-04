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
        hash=d8a7e7349e8186ee669517fec033123203ab1ab5eb061b4edafb592da877524a
        path=kbl336lsimpd08qwfbfnhy8smdarvbxy/nix-2.29.1-x86_64-linux.tar.xz
        system=x86_64-linux
        ;;
    Linux.i?86)
        hash=ae4b00e3cbe89b060d0f2548b2a7ae4f361c2856064903ed649736baad102031
        path=jya581xaqw0pck350lbvbzfmnrqcz1g3/nix-2.29.1-i686-linux.tar.xz
        system=i686-linux
        ;;
    Linux.aarch64)
        hash=5e7fbf44d4450ce68d2e0db71e6f2bc1cab59cba892c3fb30ada83c71e100ee3
        path=045g8p2mb4xafgj58w2l17k8340wwdxf/nix-2.29.1-aarch64-linux.tar.xz
        system=aarch64-linux
        ;;
    Linux.armv6l)
        hash=d0d624fe813e05a0df55621cb75d70a7510a2a317c84f9623e241d80d3d0dbef
        path=a6nsrz9p9ipyijpdl4cjgjbpvlw9dxxz/nix-2.29.1-armv6l-linux.tar.xz
        system=armv6l-linux
        ;;
    Linux.armv7l)
        hash=222f755287df338e3fdd24ca059a4adbc955e6c13d7a282a3330927554fd0abb
        path=7f20rcp0kfal73hkbcp1g2a8ynnh9zy0/nix-2.29.1-armv7l-linux.tar.xz
        system=armv7l-linux
        ;;
    Linux.riscv64)
        hash=364d5c21a15eb7cb1e3292080d889fb856f0a16e1b898fec0fa39c106992286e
        path=fskyy31mmwkzwwdfdvhh8hbndkiigc28/nix-2.29.1-riscv64-linux.tar.xz
        system=riscv64-linux
        ;;
    Darwin.x86_64)
        hash=21912ed2cb17e8354ddc386018e6e75bf4721d35d5962f53206a777822d1308c
        path=2b8wdc50w6m97fbflfd7ykzhi61s83ga/nix-2.29.1-x86_64-darwin.tar.xz
        system=x86_64-darwin
        ;;
    Darwin.arm64|Darwin.aarch64)
        hash=d91a918fda9e3aebd6892919f43e51e4f959fa60cca188cbefa6039fab0373ad
        path=2cg7527lqw2arm6j4dmdxzbwq45xm85s/nix-2.29.1-aarch64-darwin.tar.xz
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
    url=https://releases.nixos.org/nix/nix-2.29.1/nix-2.29.1-$system.tar.xz
fi

tarball=$tmpDir/nix-2.29.1-$system.tar.xz

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

echo "downloading Nix 2.29.1 binary tarball for $system from '$url' to '$tmpDir'..."
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
