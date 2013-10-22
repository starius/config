export LANG=en_US.utf8
export EDITOR=vim
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
export PATH=$PATH:/usr/local/bin
export PATH=~/bin:$PATH

HISTCONTROL=ignoredups
HISTCONTROL=ignorespace
HISTCONTROL=erasedups
shopt -s histappend
PROMPT_COMMAND='history -a; history -n'

. ~/.bashrc
