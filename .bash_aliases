alias ff=firefox

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias l='ls -CF'

alias mysshfs='sshfs -o transform_symlinks'
alias mydiff='diff -Npru'

alias mycmake="CXX='ccache g++' cmake -D CMAKE_INSTALL_PREFIX:PATH=/usr"
alias octperm="perl -e 'printf \"%o\n\",(stat shift)[2] & 07777'"

alias ssh-tor="ssh -o ProxyCommand='/usr/bin/connect -4 -S localhost:9050 %h %p'"
alias ssh-onion="ssh -o ProxyCommand='connect -R remote -5 -S 127.0.0.1:9050 %h %p'"
USER_AGENT=`ua`
alias curl-tor="curl --socks5 localhost:9050 -A '$USER_AGENT'"
alias dpaste="pastebinit -a anonymous -b http://paste.debian.net"

