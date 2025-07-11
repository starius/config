{
  description = "Qubes Debian-Minimal Template Configuration (Pinned via Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/0f0fec6440f863b2e20f0351f3ad26beedf219a8"; # fixed nix in 2.29
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs"; # Same pinned nixpkgs
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux"; # For Qubes Debian minimal.
      pkgs = import nixpkgs { inherit system; };

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
          # Nix tools and home-manager.
          pkgs.nix
          home-manager.packages.${system}.home-manager

          # Rsync is needed to sync fakeRootEnv to / .
          pkgs.rsync

          # Keyboard layout settings.
          pkgs.xorg.setxkbmap
          pkgs.xorg.xkbcomp

          # Shell environment.
          pkgs.bashInteractive
          pkgs.bash-completion
          pkgs.vim
          pkgs.tmux
          pkgs.openssh
          pkgs.autossh
          pkgs.mosh
          pkgs.man

          # Command line.
          pkgs.util-linux
          pkgs.git
          pkgs.curl
          pkgs.wget
          pkgs.unzip
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
          pkgs.sshfs
          pkgs.gocryptfs
          pkgs.openvpn
          pkgs.ffmpeg
          pkgs.qrencode
          pkgs.qrscan
          pkgs.qrtool

          # GUI.
          pkgs.xfce.xfce4-terminal
          pkgs.xfce.ristretto
          pkgs.xfce.thunar
          pkgs.firefox
          pkgs.chromium
          pkgs.qbittorrent
          pkgs.telegram-desktop
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
          pkgs.mindforger

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
          pkgs.cmakeCurses
          pkgs.clang-tools
          pkgs.gcc
          pkgs.gdb
          pkgs.valgrind

          # Deployment.
          pkgs.kubectl
          pkgs.k9s
          pkgs.docker

          # VMs and emulators.
          (pkgs.wine.override { pulseaudioSupport = true; })
          pkgs.appimage-run
        ];
      };

    in {
      packages.${system} = {
        fake-root = fakeRootEnv;
        apps = appEnv;
      };
    };
}
