#!/bin/bash
# .bashrc version ###DATE###
# curl zez.dev -Lo .bashrc
# wget zez.dev -O .bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


HISTCONTROL=ignoreboth # don't put duplicate lines or lines starting with space in the history
shopt -s histappend # append to the history file, don't overwrite it

HISTSIZE=1000
HISTFILESIZE=2000

shopt -s checkwinsize # check the window size after each command and, if necessary, update the values of LINES and COLUMNS.
shopt -s globstar #allow ** in glob
shopt -s extglob #allow extended glob matching such as ?(pattern), *(pattern), etc
shopt -s dotglob #allow globbing to match hidden files (files starting with a dot)
set +H #disable "!" expanding to history

#Avoid .* matching . and ..
GLOBIGNORE=".:.."

#disable as it causes problems with scp autocompletion
#shopt -s failglob #if doing ls *nomatch*, it will cause an error instead of passing "*nomatch*" to ls

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ll='ls -laF'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi


# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

prompt_get_git_branch() {
    title=$1
    _PROMPT_CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ $_PROMPT_CURRENT_GIT_BRANCH == "HEAD" ]]; then
        #If checking out a specific commit, we need to use --short
        _PROMPT_CURRENT_GIT_BRANCH=$(git rev-parse --short HEAD 2>/dev/null)
    fi
    if [[ ! -z $_PROMPT_CURRENT_GIT_BRANCH && $_PROMPT_CURRENT_GIT_BRANCH != "main" && $_PROMPT_CURRENT_GIT_BRANCH != "master" ]]; then
        if [[ $title == "true" ]]; then
            _PROMPT_CURRENT_GIT_BRANCH="($_PROMPT_CURRENT_GIT_BRANCH)"
        fi
        _PROMPT_CURRENT_GIT_BRANCH=" $_PROMPT_CURRENT_GIT_BRANCH"
    else
        _PROMPT_CURRENT_GIT_BRANCH=""
    fi
    echo "$_PROMPT_CURRENT_GIT_BRANCH"
}

prompt_get_mingw64() {
    title=$1
    if [[ "$MSYSTEM" == "MINGW64" ]]; then
        if [[ $title == "true" ]]; then
            echo " - MINGW64"
        elif [[ -z "$SSH_CONNECTION" ]]; then
            echo "MINGW64"
        else
            echo " MINGW64"
        fi
    else
        echo ""
    fi
}

prompt_display_user_hostname() {
    # Display user@hostname, unless we are in mingw64 (git bash) and not in ssh
    if [[ "$MSYSTEM" == "MINGW64" && -z "$SSH_CONNECTION" ]]; then
        return 1
    else
        return 0
    fi
}

PROMPT_HOSTNAME=${PROMPT_HOSTNAME:-$HOSTNAME}

if [[ $MSYSTEM == "MINGW64" ]]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;35m\]$(prompt_display_user_hostname && echo "\u@$PROMPT_HOSTNAME " || echo '')\[\033[0m\033[92m\]MINGW64\[\033[0m\] \[\033[01;34m\]\w\[\033[01;36m\]$(prompt_get_git_branch)\[\033[00m\]> '
else

    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@$PROMPT_HOSTNAME\[\033[0m\]:\[\033[01;34m\]\w\[\033[01;35m\]$(prompt_get_git_branch)\[\033[00m\]\$ '
fi

# If this is an xterm set the title to user@host: dir <branch>
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\$(prompt_display_user_hostname && echo '\u@$PROMPT_HOSTNAME: ' || echo '')\w\$(prompt_get_git_branch true)\$(prompt_get_mingw64 true)\a\]$PS1"
    ;;
*)
    ;;
esac


# enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

export PYTHONDONTWRITEBYTECODE=1

#Automatically display column names in sqlite cli and add color to prompt
#Unfortunately max sqlite prompt length is 18 chars (including escape chars) so we can only have 5 chars max displayed
§writeFile {"src": "sqliterc", "dest": "~/.sqliterc", "msg": "Added .sqliterc", "command": "sqlite3"}

#Add color to mysql prompt: "mysql user:database> "
#\001 and \002 delimit non-printing characters, so that readline/editline computes the prompt length correctly
export MYSQL_PS1=$'\001\e[01;35m\002mysql\001\e[0m\002 \001\e[01;32m\002\\u\001\e[0m\002:\001\e[01;34m\002\\d\001\e[0m\002> '

#Add color to mongodb prompt. Disabled as I don't use mongodb cli
#cat << EOF > ~/.mongorc.js
#//Note: this is automatically generated and overwritten by .bashrc
#prompt = () => "\u001b[92m"+db.getName()+"\u001b[0m>";
#EOF

§writeFile {"src": "vimrc", "dest": "~/.vimrc", "msg": "Added .vimrc"}
