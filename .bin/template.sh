sudo aptitude install gcc autossh git tmux vim mercurial python-pip mat sshfs curl ruby unzip openvpn openssl libssl-dev python3-setuptools python3-pip python-msgpack jq daemonize graphviz yarnpkg ffmpeg rsync dnsutils whois mosh p7zip-full
sudo aptitude install mplayer torchat python-qt4 python-qrcode qbittorrent pidgin pidgin-otr gimp inkscape ristretto geany chromium python3-pyqt5
sudo aptitude remove icedove thunderbird nano avahi-daemon unattended-upgrades
sudo systemctl disable systemd-resolved tor.service
sudo sed 's@RUN_DAEMON="yes"@RUN_DAEMON="no"@' -i /etc/default/tor

# https://www.qubes-os.org/doc/vm-sudo/#replacing-password-less-root-access-with-dom0-user-prompt
