{
  description = "Pinned Nix environment for Qubes templates and Debian servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dfd9566f82a6e1d55c30f861879186440614696e";
    rust-overlay.url = "github:oxalica/rust-overlay/199eeb6748116f7da4fbd3a680bc854e99d9132b";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux"; # For Qubes Debian minimal.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import rust-overlay)
        ];
      };

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

      mkFakeRootEnv = name: paths: pkgs.symlinkJoin {
        inherit name paths;
      };

      mkAppEnv = name: paths: pkgs.buildEnv {
        inherit name paths;
      };

      commonFakeRootPaths = [
        nixProfiled
        bashCompletionProfile
      ];

      desktopFakeRootPaths = [
        etcEnvironment
        x11KeyboardConf
      ];

      # Shared command line and development environment.
      serverAppPaths = [
        # Nix tools.
        pkgs.nix

        # Rsync is needed to sync fakeRootEnv to / .
        pkgs.rsync

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
        pkgs.gh
        pkgs.wdiff
        pkgs.colordiff
        pkgs.curl
        pkgs.grpcurl
        pkgs.wget
        pkgs.gzip
        pkgs.zip
        pkgs.unzip
        pkgs.zstd
        pkgs.unrar-free
        pkgs.openssl
        pkgs.jq
        pkgs.yq-go
        pkgs.xxd
        pkgs.dos2unix
        pkgs.graphviz
        pkgs.dnsutils
        pkgs.whois
        pkgs.p7zip
        pkgs.bzip2
        pkgs.wireguard-tools
        pkgs.nettools
        pkgs.steghide
        pkgs.mat2
        pkgs.exiftool
        pkgs.sshfs
        pkgs.gocryptfs
        pkgs.openvpn
        pkgs.sing-box
        pkgs.ffmpeg
        pkgs.imagemagick
        pkgs.qrencode
        pkgs.qrtool
        pkgs.opentimestamps-client
        pkgs.tor
        pkgs.codex
        pkgs.gemini-cli-bin
        pkgs.opencode
        pkgs.termsvg
        pkgs.ripgrep
        pkgs.ntfs3g
        pkgs.bitcoin
        pkgs.lnd
        pkgs.lightning-loop
        pkgs.openai-whisper
        pkgs.poppler-utils # pdftotext
        pkgs.csvkit
        pkgs.discordo
        pkgs.yt-dlp
        pkgs.go-grip

        # Keybase.
        pkgs.keybase
        pkgs.kbfs
        pkgs.fuse

        # Development.
        pkgs.perf
        pkgs.flamegraph
        pkgs.nodejs_24
        pkgs.yarn
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
        pkgs.nixfmt
        pkgs.autoconf
        pkgs.automake
        pkgs.libtool

        # Deployment.
        pkgs.kubectl
        pkgs.k9s
        pkgs.docker
        pkgs.helm

        # VMs and emulators.
        pkgs.qemu-user
      ];

      desktopAppPaths = [
        # Keyboard layout settings.
        pkgs.setxkbmap
        pkgs.xkbcomp

        # GUI.
        pkgs.xfce4-terminal
        pkgs.lxterminal
        pkgs.ristretto
        pkgs.thunar
        pkgs.firefox
        pkgs.ungoogled-chromium
        pkgs.qbittorrent
        pkgs.telegram-desktop
        pkgs.ayugram-desktop
        pkgs.keepassxc
        pkgs.geany
        (pkgs.mplayer.override { pulseSupport = true; })
        pkgs.evince
        # pkgs.calibre https://github.com/NixOS/nixpkgs/pull/494483
        pkgs.gimp3
        pkgs.inkscape
        pkgs.abiword
        pkgs.gnumeric
        pkgs.gnuplot
        pkgs.electrum
        pkgs.keybase-gui
        (pkgs.wine.override { pulseaudioSupport = true; })

        # Games.
        pkgs.vcmi
      ];

      serverFakeRootEnv = mkFakeRootEnv "debian-server-fake-root" commonFakeRootPaths;
      fakeRootEnv = mkFakeRootEnv "qubes-fake-root" (commonFakeRootPaths ++ desktopFakeRootPaths);

      serverAppEnv = mkAppEnv "debian-server-env" serverAppPaths;
      appEnv = mkAppEnv "qubes-template-env" (serverAppPaths ++ desktopAppPaths);

    in {
      packages.${system} = {
        fake-root = fakeRootEnv;
        fake-root-server = serverFakeRootEnv;
        apps = appEnv;
        apps-server = serverAppEnv;
      };
    };
}
