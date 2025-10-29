{
  description = "Qubes Debian-Minimal Template Configuration (Pinned via Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/870493f9a8cb0b074ae5b411b2f232015db19a65";
    rust-overlay.url = "github:oxalica/rust-overlay/a8143c74e5ed8cdbca3c96d4362b6392577481ff";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux"; # For Qubes Debian minimal.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };

      # Create /etc/environment .
      etcEnvironment = pkgs.writeTextDir "etc/environment" ''
        QT_XCB_GL_INTEGRATION=none
      '';

      # Create /etc/X11/xorg.conf.d/00-keyboard.conf .
      x11KeyboardConf = pkgs.writeTextDir "etc/X11/xorg.conf.d/00-keyboard.conf" ''
        Section "InputClass"
            Identifier "system-keyboard"
            MatchIsKeyboard "on"
            Option "XkbLayout" "us,ru"
            Option "XkbOptions" "grp:rctrl_rshift_toggle"
        EndSection
      '';

      # /etc/profile.d/99-qubes-nix.sh .
      nixProfiled = pkgs.writeTextDir "etc/profile.d/99-qubes-nix.sh" ''
        export PATH=/nix/var/nix/profiles/default/bin:$PATH
        export NIX_REMOTE=daemon
      '';

      # Setup bash completion.
      bashCompletionProfile = pkgs.writeTextDir "etc/profile.d/99-bash-completion.sh" ''
        # Enable programmable completion features.
        if [ -f /nix/var/nix/profiles/default/etc/profile.d/bash_completion.sh ]; then
          . /nix/var/nix/profiles/default/etc/profile.d/bash_completion.sh
        fi
      '';

      # Fake root only for /etc .
      fakeRootEnv = pkgs.symlinkJoin {
        name = "qubes-fake-root";
        paths = [
          etcEnvironment
          x11KeyboardConf
          nixProfiled
          bashCompletionProfile
        ];
      };

      # Program environment (Firefox, terminal, etc.) stays in nix store.
      appEnv = pkgs.buildEnv {
        name = "qubes-template-env";
        paths = [
          # Nix tools.
          pkgs.nix

          # Rsync is needed to sync fakeRootEnv to / .
          pkgs.rsync

          # Keyboard layout settings.
          pkgs.xorg.setxkbmap
          pkgs.xorg.xkbcomp

          # Shell environment.
          pkgs.bashInteractive
          pkgs.bash-completion
          pkgs.zsh
          pkgs.fish
          pkgs.vim
          pkgs.ed
          pkgs.tmux
          pkgs.openssh
          pkgs.autossh
          pkgs.mosh
          pkgs.man

          # Command line.
          pkgs.util-linux
          pkgs.dateutils
          pkgs.ascii
          pkgs.file
          pkgs.git
          pkgs.git-lfs
          pkgs.curl
          pkgs.grpcurl
          pkgs.wget
          pkgs.gzip
          pkgs.zip
          pkgs.unzip
          pkgs.unrar-free
          pkgs.openssl
          pkgs.jq
          pkgs.xxd
          pkgs.dos2unix
          pkgs.daemonize
          pkgs.graphviz
          pkgs.dnsutils
          pkgs.whois
          pkgs.p7zip
          pkgs.bzip2
          pkgs.wireguard-tools
          pkgs.nettools
          pkgs.netcat-openbsd
          pkgs.steghide
          pkgs.mat2
          pkgs.exiftool
          pkgs.sshfs
          pkgs.gocryptfs
          pkgs.openvpn
          pkgs.ffmpeg
          pkgs.imagemagick
          pkgs.qrencode
          pkgs.qrtool
          pkgs.opentimestamps-client
          pkgs.tor
          pkgs.codex
          pkgs.gemini-cli-bin
          pkgs.termsvg
          pkgs.ripgrep

          # GUI.
          pkgs.xfce.xfce4-terminal
          pkgs.lxterminal
          pkgs.xfce.ristretto
          pkgs.xfce.thunar
          pkgs.firefox
          pkgs.chromium
          pkgs.qbittorrent
          pkgs.telegram-desktop
          pkgs.discordo
          pkgs.keepassxc
          pkgs.geany
          (pkgs.mplayer.override { pulseSupport = true; })
          pkgs.evince
          pkgs.calibre
          pkgs.gimp3
          pkgs.inkscape
          pkgs.abiword
          pkgs.gnumeric
          pkgs.gnuplot
          pkgs.electrum

          # Keybase.
          pkgs.keybase
          pkgs.keybase-gui
          pkgs.kbfs
          pkgs.fuse

          # Development.
          pkgs.gnumake
          pkgs.go
          pkgs.gotools
          pkgs.golangci-lint
          pkgs.goperf
          pkgs.asmfmt
          pkgs.cmakeCurses
          pkgs.clang-tools
          pkgs.gcc
          pkgs.yasm
          pkgs.gdb
          pkgs.valgrind
          pkgs.postgresql
          pkgs.sqlite
          # Rust toolchain with musl target preinstalled (static builds).
          (pkgs.rust-bin.stable.latest.default.override {
            targets = [ "x86_64-unknown-linux-musl" ];
          })
          # Musl cross-compiler (for linking static binaries).
          pkgs.pkgsCross.musl64.stdenv.cc
          pkgs.pkg-config
          pkgs.nixfmt-rfc-style

          # Deployment.
          pkgs.kubectl
          pkgs.k9s
          pkgs.docker

          # VMs and emulators.
          (pkgs.wine.override { pulseaudioSupport = true; })
          pkgs.appimage-run
          pkgs.qemu-user
        ];
      };

    in {
      packages.${system} = {
        fake-root = fakeRootEnv;
        apps = appEnv;
      };
    };
}
