# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# append to the history file, don't overwrite it
shopt -s histappend

# prior to issuing each primary prompt:
#  append history lines from this session to the history file
#  read all history lines not already read from the history file
PROMPT_COMMAND='history -a; history -n'

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000000
HISTFILESIZE=1000000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export LANG=en_US.utf8
export EDITOR=vim

export PATH="$HOME/.luarocks/bin:$PATH"
export PATH="$PATH:$HOME/.linuxbrew/bin"
export PATH="$PATH:$HOME/node_modules/phantomjs/lib/phantom/bin/"
export PATH="$PATH:$HOME/.gem/ruby/1.9.1/bin"
export PATH="$PATH:$HOME/.local/bin"

export LUA_PATH="/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;$HOME/.luarocks/share/lua/5.1/?.lua;$HOME/.luarocks/share/lua/5.1/?/init.lua;/usr/share/lua/5.1//?.lua;/usr/share/lua/5.1//?/init.lua;./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/share/luajit-2.1.0-alpha/?.lua;$HOME/.luaroot/share/lua/5.1/?.lua;$HOME/.luaroot/share/lua/5.1/?/init.lua"
export LUA_CPATH="/usr/local/lib/lua/5.1/?.so;$HOME/.luarocks/lib/lua/5.1/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;$HOME/.luaroot/lib/lua/5.1/?.so"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
export PATH=$PATH:/usr/local/bin
export PATH=$HOME/.bin:$PATH

export PATH=$HOME/bin:$PATH

export GOPATH=$HOME
export PATH=$HOME/.goroot/bin:$HOME/.goroot/misc/nacl:$PATH
export PATH=$GOPATH/bin:$PATH
# Install bash completion for Go: go get github.com/posener/complete/gocomplete
if [ -f $HOME/bin/gocomplete ]; then
    complete -C $HOME/bin/gocomplete go
fi

export PATH=$HOME/.naclbin:$PATH

export PATH=$HOME/.luaroot/bin:$PATH

export PATH=$HOME/.protobuf-root/bin:$PATH

export PATH=$HOME/.cmake-root/bin:$PATH

export PATH=$HOME/.rust-root/bin:$PATH

export PATH=$HOME/.git-root/bin:$PATH

export PATH=$HOME/.wget-root/bin:$PATH

export PATH=$HOME/.astyle-root/bin:$PATH

export PATH=$HOME/.nodejs-root/bin:$PATH

export PATH=$HOME/.ruby-build-root/bin:$PATH
export PATH=$HOME/.ruby-root/bin:$PATH
