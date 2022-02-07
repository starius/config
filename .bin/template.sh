sudo apt-get install git tmux vim mercurial curl unzip openssl libssl-dev jq daemonize graphviz dnsutils whois p7zip-full build-essential
sudo apt-get install autossh mat sshfs ruby openvpn python3-setuptools yarnpkg ffmpeg rsync mosh
sudo apt-get install mplayer qrencode qbittorrent pidgin pidgin-otr gimp inkscape ristretto geany chromium python3-pyqt5
sudo apt-get remove icedove thunderbird nano avahi-daemon unattended-upgrades
sudo systemctl disable systemd-resolved tor.service
sudo sed 's@RUN_DAEMON="yes"@RUN_DAEMON="no"@' -i /etc/default/tor

# https://www.qubes-os.org/doc/vm-sudo/#replacing-password-less-root-access-with-dom0-user-prompt
