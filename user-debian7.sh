if [ ! -d .hg ]; then
    cd && hg clone http://bitbucket.org/starius/config
    mv config/.hg ~
    rm -r config
    cd ~ && hg revert -a
fi
if [ ! -d helpme ]; then
    cd && hg clone http://bitbucket.org/starius/helpme
fi
mkdir -p mycode

gsettings set org.gnome.desktop.background show-desktop-icons true

# gsettings set \
#     org.gnome.settings-daemon.plugins.media-keys.custom-keybindings.custom0 \
#     binding "<Primary><Alt>t"
# gsettings set \
#     org.gnome.settings-daemon.plugins.media-keys.custom-keybindings.custom0 \
#     command "gnome-terminal"
# gsettings set \
#     org.gnome.settings-daemon.plugins.media-keys.custom-keybindings.custom0 \
#     name "gnome-terminal"

#gsettings set org.gnome.desktop.background picture-uri \
#    /usr/share/pixmaps/backgrounds/gnome/nature/Dune.jpg


