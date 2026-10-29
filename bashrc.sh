#!/bin/bash
# .bashrc version 2026-10-29
# curl zez.dev -Lo .bashrc
# wget zez.dev -O .bashrc

# If not running interactively, don't do anything
[[ $- == *i* ]] || return 0


HISTCONTROL=ignoreboth # don't put duplicate lines or lines starting with space in the history
shopt -s histappend # append to the history file, don't overwrite it
#[[ $PROMPT_COMMAND == *"history -a"* ]] || PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" # write each command to the history file once it finishes, instead of on exit, so that it is not lost if the terminal is killed - disabled for now for testing

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

#Same as gacp in profile.ps1
if command -v git >/dev/null; then
    gacp() { git add -A && git commit --allow-empty-message -m "$1" && git push; }
fi

[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases


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
[[ $TERM == xterm* || $TERM == rxvt* ]] && PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\$(prompt_display_user_hostname && echo '\u@$PROMPT_HOSTNAME: ' || echo '')\w\$(prompt_get_git_branch true)\$(prompt_get_mingw64 true)\a\]$PS1"


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
if command -v 'sqlite3' >/dev/null && [[ ! -f "$HOME/.sqliterc" || $(stat -c %Y "$HOME/.sqliterc") -lt 1793083095 ]]; then
    mkdir -p "$(dirname "$HOME/.sqliterc")"
    printf '%s' $'--Note: this is automatically generated and overwritten by .bashrc
.headers ON
.mode columns
.nullvalue <NULL>
.prompt "\x01\x1b[92m\x02sql\x01\x1b[0m\x02> " "\x01\x1b[36m\x02...\x01\x1b[0m\x02> "
' > "$HOME/.sqliterc"
    echo '[.bashrc] Added .sqliterc'
fi

#Add color to mysql prompt: "mysql user:database> "
#\001 and \002 delimit non-printing characters, so that readline/editline computes the prompt length correctly
export MYSQL_PS1=$'\001\e[01;35m\002mysql\001\e[0m\002 \001\e[01;32m\002\\u\001\e[0m\002:\001\e[01;34m\002\\d\001\e[0m\002> '

#Add color to mongodb prompt. Disabled as I don't use mongodb cli
#cat << EOF > ~/.mongorc.js
#//Note: this is automatically generated and overwritten by .bashrc
#prompt = () => "\u001b[92m"+db.getName()+"\u001b[0m>";
#EOF

if [[ ! -f "$HOME/.vimrc" || $(stat -c %Y "$HOME/.vimrc") -lt 1793084032 ]]; then
    mkdir -p "$(dirname "$HOME/.vimrc")"
    printf '%s' $'"Note: this is automatically generated and overwritten by .bashrc

" Reopen the last edited position in files
au BufReadPost * if line("\'\\"") > 1 && line("\'\\"") <= line("$") | exe "normal! g\'\\"" | endif
"Syntax coloration
syntax on
"Load plugins based on file type
filetype on
"Display line numbers. Todo: too distracting.
"set number
"Inserts spaces when pressing the tab key
set expandtab
"Set tab width to 4 spaces
set tabstop=4
set softtabstop=4
set shiftwidth=4

"Do not continue comment when pressing Enter
autocmd FileType * set formatoptions-=cro

"Disable autoindent, as it messes up pasting
filetype indent off
set noautoindent
set nocindent
set nosmartindent
set indentexpr&

"Highlight matching brackets
set showmatch

"Case insensitive matching in search
set ignorecase
set smartcase
"Highlight search matches
set hlsearch

"Allow selecting with the mouse
set mouse=a

"The following is normally in debian.vim but it does not get sourced if vimrc exists

set nocompatible	" Use Vim defaults instead of 100% vi compatibility
set backspace=indent,eol,start	" more powerful backspacing
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set nomodeline
" Suffixes that get lower priority when doing tab completion for filenames.
" These are files we are not likely to want to edit or read.
set suffixes=.bak,~,.swp,.o,.info,.aux,.log,.dvi,.bbl,.blg,.brf,.cb,.ind,.idx,.ilg,.inx,.out,.toc

" We know xterm-debian is a color terminal
if &term =~ "xterm-debian" || &term =~ "xterm-xfree86"
  set t_Co=16
  set t_Sf=\x1b[3%dm
  set t_Sb=\x1b[4%dm
endif

" Some Debian-specific things
if has(\'gui\')
  " Must define this within the :if so it does not cause problems with
  " vim-tiny (which does not have +eval)
  function! <SID>MapExists(name, modes)
    for mode in split(a:modes, \'\\zs\')
      if !empty(maparg(a:name, mode))
        return 1
      endif
    endfor
    return 0
  endfunction

  " Make shift-insert work like in Xterm
  autocmd GUIEnter * if !<SID>MapExists("<S-Insert>", "nvso") | execute "map <S-Insert> <MiddleMouse>" | endif
  autocmd GUIEnter * if !<SID>MapExists("<S-Insert>", "ic") | execute "map! <S-Insert> <MiddleMouse>" | endif
endif

" Set paper size from /etc/papersize if available (Debian-specific)
if filereadable("/etc/papersize")
  let s:papersize = matchstr(readfile(\'/etc/papersize\', \'\', 1), \'\\p*\')
  if strlen(s:papersize)
    exe "set printoptions+=paper:" . s:papersize
  endif
endif
' > "$HOME/.vimrc"
    echo '[.bashrc] Added .vimrc'
fi

#Mitigate supply chain attacks: don't install package versions released less than 52 days ago (most malicious versions are detected and removed by then), and don't run install scripts
if [[ -z $MSYSTEM ]]; then
    #If the config file already exists, use the program to edit it, keeping the other settings (eg auth tokens)
    #The global npm config is usually only writable by root. For pnpm, --location=global is the config of the current user
    if command -v 'npm' >/dev/null && [[ ! -f "$HOME/.npmrc" || $(stat -c %Y "$HOME/.npmrc") -lt 1793199795 ]]; then
        if [[ -f "$HOME/.npmrc" ]]; then
            { npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=user; } && { [[ $EUID -ne 0 ]] || npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=global; } && echo '[.bashrc] Set npm security settings'
        else
            mkdir -p "$(dirname "$HOME/.npmrc")"
            printf '%s' '# Don'\''t install package versions released less than 52 days ago. Needs npm 11.10+, older versions display a warning
min-release-age=52
ignore-scripts=true
# Git dependencies bypass the registry, so min-release-age does not apply to them. Default in npm 12
allow-git=none
' > "$HOME/.npmrc"
            echo '[.bashrc] Set npm security settings'
        fi
    fi
    #pnpm 11+ reads its settings from config.yaml instead of rc. If config.yaml does not exist, pnpm 10 is presumably installed, so set the settings in rc with the commands
    #config.yaml is still written, so that the commands are not run again and pnpm is configured once upgraded
    if command -v pnpm >/dev/null; then
        if [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml") -lt 1793199796 ]]; then
            if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" ]]; then
                { pnpm config set minimumReleaseAge 74880 --location=global; } && { pnpm config set ignoreScripts true --location=global; } && { pnpm config set trustPolicy no-downgrade --location=global; } && echo '[.bashrc] Set pnpm security settings'
            else
                if { pnpm config set minimum-release-age 74880 --location=global; } && { pnpm config set trust-policy no-downgrade --location=global; } && { pnpm config set block-exotic-subdeps true --location=global; }; then
                    mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml")"
                    printf '%s' '# Don'\''t install package versions released less than 52 days ago (in minutes)
minimumReleaseAge: 74880
ignoreScripts: true
# Fail if a package version is published with less trust evidence (eg without provenance) than the previous versions, which is typical of stolen tokens
trustPolicy: no-downgrade
' > "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml"
                    echo '[.bashrc] Set pnpm security settings'
                fi
            fi
        fi
    fi
    if command -v 'uv' >/dev/null && [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml") -lt 1793199799 ]]; then
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml")"
        printf '%s' '# Don'\''t install package versions released less than 52 days ago. Needs uv 0.9.17+, older versions fail to parse the duration
exclude-newer = "52 days"
# Building source distributions runs arbitrary code. Use --no-config to install a package that has no wheels
no-build = true
' > "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml"
        echo '[.bashrc] Set uv security settings'
    fi
    if command -v 'bun' >/dev/null && [[ ! -f "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml") -lt 1793199804 ]]; then
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml")"
        printf '%s' '[install]
# Don'\''t install package versions released less than 52 days ago (in seconds)
minimumReleaseAge = 4492800
ignoreScripts = true
' > "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml"
        echo '[.bashrc] Set bun security settings'
    fi
fi
