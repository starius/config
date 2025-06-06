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
