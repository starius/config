#!/bin/bash

set -xue

RUST_ROOT="${HOME}/.rust-root"
RUST_SRC="${HOME}/src/github.com/rust-lang/rust"
CARGO_SRC="${HOME}/src/github.com/rust-lang/cargo"

if [ ! -d "$RUST_SRC" ]; then
    mkdir -p "$RUST_SRC"
    git clone https://github.com/rust-lang/rust "$RUST_SRC"
fi

RUST_BUILD=$(mktemp -d)
cd "$RUST_BUILD" && "${RUST_SRC}"/configure \
    --prefix="$RUST_ROOT" \
    --disable-docs
make -C "$RUST_BUILD" -j 4
make -C "$RUST_BUILD" install

# Cargo

if [ ! -d "$CARGO_SRC" ]; then
    mkdir -p "$CARGO_SRC"
    git clone --recursive https://github.com/rust-lang/cargo "$CARGO_SRC"
fi

CARGO=$(find "$RUST_BUILD" -name cargo | grep stage0/bin/cargo)
CARGO_BIN=$(echo "$CARGO" | sed 's@bin/cargo@bin@')
export PATH="${CARGO_BIN}:${PATH}"

CARGO_BUILD=$(mktemp -d)
cd "$CARGO_BUILD" && \
    "${CARGO_SRC}"/configure \
    --prefix="$RUST_ROOT"
make -C "$CARGO_BUILD" -j 4
make -C "$CARGO_BUILD" install
rm -rf "$CARGO_BUILD"

rm -rf "$RUST_BUILD"
