{
  description = "Qubes Debian-Minimal Template Configuration (Pinned via Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/11cb3517b3af6af300dd6c055aeda73c9bf52c48"; # pinned nixpkgs 25.05.
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs"; # Same pinned nixpkgs
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux"; # For Qubes Debian minimal.
      pkgs = import nixpkgs { inherit system; };

      # Create /etc/environment .
      etcEnvironment = pkgs.writeTextDir "etc/environment" ''
        LANG=en_US.UTF-8
        LANGUAGE=en_US:en
        LC_ALL=en_US.UTF-8
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

      # Fake root only for /etc .
      fakeRootEnv = pkgs.symlinkJoin {
        name = "qubes-fake-root";
        paths = [
          etcEnvironment
          x11KeyboardConf
          nixProfiled
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

          # Command line.
          pkgs.util-linux
          pkgs.vim
          pkgs.tmux
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
          pkgs.wireguard-tools
          pkgs.nettools
          pkgs.netcat-openbsd

          # GUI.
          pkgs.xfce.xfce4-terminal
          pkgs.firefox
          pkgs.chromium
          pkgs.qbittorrent
          pkgs.telegram-desktop
          pkgs.keepassxc

          # Keybase.
          pkgs.keybase
          pkgs.keybase-gui
          pkgs.kbfs
          pkgs.fuse

          # Development.
          pkgs.go
        ];
      };

    in {
      packages.${system} = {
        fake-root = fakeRootEnv;
        apps = appEnv;
      };
    };
}
