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
