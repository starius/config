# http://stackoverflow.com/a/36953319

tmux_home=~/.tmux
tmux_version="$(tmux -V | cut -c 6-)"

if [[ $(echo "$tmux_version >= 1.9" | bc) -eq 1 ]] ; then
    tmux source-file "$tmux_home/cd_pwd.conf"
fi
