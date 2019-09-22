sudo aptitude install gcc autossh mplayer git tmux vim torchat mercurial python-qt4 python-pip qbittorrent pidgin pidgin-otr gimp mat ristretto geany sshfs curl ruby chromium unzip openvpn openssl libssl-dev python3-setuptools python3-pyqt5 python3-pip python-msgpack jq daemonize graphviz yarnpkg ffmpeg rsync
sudo aptitude remove icedove thunderbird nano avahi-daemon unattended-upgrades
sudo systemctl disable systemd-resolved tor.service
sudo sed 's@RUN_DAEMON="yes"@RUN_DAEMON="no"@' -i /etc/default/tor

# https://www.qubes-os.org/doc/vm-sudo/#replacing-password-less-root-access-with-dom0-user-prompt
