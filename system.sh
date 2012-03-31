apt-get install etckeeper
apt-get -y install vim tmux aptitude mercurial
update-alternatives --set editor /usr/bin/vim.basic
sed '/cdrom/s@^@#@' -i /etc/apt/sources.list
cp google-*.list opera.list squeeze-backports.list /etc/apt/sources.list.d/
cp sid.list /etc/apt/sources.list.d/
echo 'APT::Default-Release "stable";' > /etc/apt/apt.conf
wget https://bitbucket.org/starius/config/raw/tip/packages.dpkg -O - | \
  dpkg --set-selections
apt-get update
apt-get -y --force-yes dselect-upgrade
if (! grep -q ' /tmp' /etc/fstab ); then
    echo 'tmpfs /tmp tmpfs defaults,size=10g 0 0' >> /etc/fstab
fi

wget http://atdot.ch/scr/files/0.8/skype-call-recorder-debian_0.8_i386.deb \
    -O skype-call-recorder-debian_0.8_i386.deb
dpkg -i skype-call-recorder-debian_0.8_i386.deb
apt-get -f -y install

apt-file update

