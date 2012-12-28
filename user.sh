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

gconftool-2 -t str -s /apps/metacity/global_keybindings/run_command_terminal \
    "<Control><Alt>t"
gconftool-2 -t str -s /desktop/gnome/background/picture_filename \
    /usr/share/pixmaps/backgrounds/gnome/nature/Dune.jpg
gconftool-2 -t str -s /desktop/gnome/applications/browser/exec \
    /opt/google/chrome/google-chrome
gconftool-2 -s /desktop/gnome/peripherals/touchpad/disable_while_typing \
    -t bool false
gconftool-2 -s /desktop/gnome/peripherals/touchpad/scroll_method \
    -t int 1

gconftool-2 -t string -s /desktop/gnome/url-handlers/magnet/command \
        "/usr/bin/qbittorrent '%s'"
gconftool-2 -t bool -s /desktop/gnome/url-handlers/magnet/needs_terminal false
gconftool-2 -t bool -s /desktop/gnome/url-handlers/magnet/enabled true

gconftool-2 -s /apps/gnome-terminal/profiles/Default/scrollbar_position \
    -t string hidden
gconftool-2 -s /apps/gnome-terminal/profiles/Default/default_show_menubar \
    -t bool false

gconftool-2 -s /desktop/gnome/peripherals/keyboard/kbd/layouts \
    -t list --list-type string '[us,ru]'
gconftool-2 -s /desktop/gnome/peripherals/keyboard/kbd/options \
    -t list --list-type string '[grp	grp:ctrl_shift_toggle]'

gconftool-2 -s /apps/guake/style/background/transparency -t int 25
gconftool-2 -s /apps/guake/style/background/color -t string '#ffffffffffff'

