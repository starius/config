# Turn Qubes Minimal Debian template into "Nixos"

In Dom0:

```
qubes-dom0-update qubes-template-debian-12-minimal
qvm-clone debian-12-minimal mynix
qvm-prefs mynix netvm sys-firewall
```

Copy this directory to `mynix:/home/user/nix`.

```
dom0$ qvm-run --user=root mynix xterm
mynix# cd /home/user/nix
mynix# ./bootstrap.sh
```

Then in Qubes go to `Settings > Applications` of `mynix` and press the button
"Refresh applications".

Shutdown `mynix`.

Create AppVM (say `torrent`) using `mynix` as `TemplaveVM`. It should work.

When you need to add more packages, after changing nix files, just re-run
`bootstrap.sh` script.

## Try extra packages from pinned nixpkgs

After `bootstrap.sh`, `nixpkgs` is pinned in the system flake registry to the
same locked GitHub revision as this flake. The `/nix/var/nix/gcroots/qubes-nixpkgs`
symlink is still kept only as a GC root and for old-style `NIX_PATH` usage.

Use:

```bash
nix shell nixpkgs#PACKAGE_NAME
```

Examples:

```bash
nix shell nixpkgs#htop
nix shell nixpkgs#jq nixpkgs#ripgrep
nix shell nixpkgs#yt-dlp --command yt-dlp --version
```

If you ever override your registry and want to force using this repo's pinned
inputs directly:

```bash
nix shell --inputs-from path:/home/user/nix nixpkgs#PACKAGE_NAME
```
