# http://stackoverflow.com/a/36953319

tmux_home=~/.tmux
tmux_version="$(tmux -V | cut -c 6-)"

# If the version is >= 1.9:

if echo -e "${tmux_version}\n1.9" | sort -V | head -1 | egrep '^1.9$'; then
    tmux source-file "$tmux_home/cd_pwd.conf"
fi
