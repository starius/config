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

