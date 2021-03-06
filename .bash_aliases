alias ff=firefox

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias l='ls -CF'

alias myhd='hexdump -v -e "1/1 \"%020_ax: \"" -e "16/1 \"%02x \" " -e "1/1 \" |\"" -e "16/1 \"%_p\"" -e "1/1 \"|\n\""'

alias mysshfs='sshfs -o transform_symlinks'
alias mydiff='diff -Npru'

alias mycmake="CXX='ccache c++' cmake -D CMAKE_INSTALL_PREFIX:PATH=/usr"
alias octperm="perl -e 'printf \"%o\n\",(stat shift)[2] & 07777'"

# ssh -o ProxyCommand="nc -X 5 -x localhost:9050 %h %p" host
alias ssh-tor="ssh -o ProxyCommand='/usr/bin/connect -5 -S localhost:9050 %h %p'"
alias ssh-onion="ssh -o ProxyCommand='connect -R remote -5 -S 127.0.0.1:9050 %h %p'"
alias curl-tor="curl --socks5 localhost:9050"
alias dpaste="pastebinit -a anonymous -b http://paste.debian.net"
alias nasplayer="AUDIOSERVER=tcp/127.0.0.1:8008 mplayer -ao nas"

