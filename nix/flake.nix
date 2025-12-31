{
  description = "Qubes Debian-Minimal Template Configuration (Pinned via Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/a672be65651c80d3f592a89b3945466584a22069";
    rust-overlay.url = "github:oxalica/rust-overlay/769156779b41e8787a46ca3d7d76443aaf68be6f";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };

          rustMuslTarget =
            lib.replaceStrings [ "-linux" ] [ "-unknown-linux-musl" ]
              pkgs.stdenv.hostPlatform.system;

          muslCrossCc =
            if pkgs.stdenv.isx86_64
            then pkgs.pkgsCross.musl64.stdenv.cc
            else pkgs.pkgsCross.aarch64-multiplatform-musl.stdenv.cc;

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

          # Packages only shipped for x86_64-linux.
          x86OnlyPackages = with pkgs; [
            keybase
            keybase-gui
            kbfs
            (wine.override { pulseaudioSupport = true; })
          ];

          # Program environment (Firefox, terminal, etc.) stays in nix store.
          appEnv = pkgs.buildEnv {
            name = "qubes-template-env";
            paths =
              [
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
                pkgs.zstd
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
                pkgs.ntfs3g
                pkgs.bitcoin
                pkgs.lnd
                pkgs.lightning-loop
                pkgs.openai-whisper
                pkgs.fuse

                # GUI.
                pkgs.xfce.xfce4-terminal
                pkgs.lxterminal
                pkgs.xfce.ristretto
                pkgs.xfce.thunar
                pkgs.firefox
                pkgs.ungoogled-chromium
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
                pkgs.yt-dlp

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
                  targets = [ rustMuslTarget ];
                })
                # Musl cross-compiler (for linking static binaries).
                muslCrossCc
                pkgs.pkg-config
                pkgs.nixfmt-rfc-style

                # Deployment.
                pkgs.kubectl
                pkgs.k9s
                pkgs.docker

                # VMs and emulators.
                pkgs.appimage-run
                pkgs.qemu-user
              ]
              ++ lib.optionals pkgs.stdenv.isx86_64 x86OnlyPackages;
          };
        in {
          fake-root = fakeRootEnv;
          apps = appEnv;
        });
    };
}
