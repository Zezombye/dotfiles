#!/bin/bash
# .bashrc version 2026-10-28
# curl zez.dev -Lo .bashrc
# wget zez.dev -O .bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


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
if [[ -f "$HOME/.sqliterc" ]] && [[ $(stat -c %Y "$HOME/.sqliterc") -ge 1793083095 ]]; then
    : # Already up to date
elif ! command -v 'sqlite3' >/dev/null; then
    : # sqlite3 is not installed
else
    mkdir -p "$(dirname "$HOME/.sqliterc")"
    echo 'LS1Ob3RlOiB0aGlzIGlzIGF1dG9tYXRpY2FsbHkgZ2VuZXJhdGVkIGFuZCBvdmVyd3JpdHRlbiBieSAuYmFzaHJjCi5oZWFkZXJzIE9OCi5tb2RlIGNvbHVtbnMKLm51bGx2YWx1ZSA8TlVMTD4KLnByb21wdCAiARtbOTJtAnNxbAEbWzBtAj4gIiAiARtbMzZtAi4uLgEbWzBtAj4gIgo=' | base64 -d > "$HOME/.sqliterc"
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

if [[ -f "$HOME/.vimrc" ]] && [[ $(stat -c %Y "$HOME/.vimrc") -ge 1793084032 ]]; then
    : # Already up to date
else
    mkdir -p "$(dirname "$HOME/.vimrc")"
    echo 'Ik5vdGU6IHRoaXMgaXMgYXV0b21hdGljYWxseSBnZW5lcmF0ZWQgYW5kIG92ZXJ3cml0dGVuIGJ5IC5iYXNocmMKCiIgUmVvcGVuIHRoZSBsYXN0IGVkaXRlZCBwb3NpdGlvbiBpbiBmaWxlcwphdSBCdWZSZWFkUG9zdCAqIGlmIGxpbmUoIidcIiIpID4gMSAmJiBsaW5lKCInXCIiKSA8PSBsaW5lKCIkIikgfCBleGUgIm5vcm1hbCEgZydcIiIgfCBlbmRpZgoiU3ludGF4IGNvbG9yYXRpb24Kc3ludGF4IG9uCiJMb2FkIHBsdWdpbnMgYmFzZWQgb24gZmlsZSB0eXBlCmZpbGV0eXBlIG9uCiJEaXNwbGF5IGxpbmUgbnVtYmVycy4gVG9kbzogdG9vIGRpc3RyYWN0aW5nLgoic2V0IG51bWJlcgoiSW5zZXJ0cyBzcGFjZXMgd2hlbiBwcmVzc2luZyB0aGUgdGFiIGtleQpzZXQgZXhwYW5kdGFiCiJTZXQgdGFiIHdpZHRoIHRvIDQgc3BhY2VzCnNldCB0YWJzdG9wPTQKc2V0IHNvZnR0YWJzdG9wPTQKc2V0IHNoaWZ0d2lkdGg9NAoKIkRvIG5vdCBjb250aW51ZSBjb21tZW50IHdoZW4gcHJlc3NpbmcgRW50ZXIKYXV0b2NtZCBGaWxlVHlwZSAqIHNldCBmb3JtYXRvcHRpb25zLT1jcm8KCiJEaXNhYmxlIGF1dG9pbmRlbnQsIGFzIGl0IG1lc3NlcyB1cCBwYXN0aW5nCmZpbGV0eXBlIGluZGVudCBvZmYKc2V0IG5vYXV0b2luZGVudApzZXQgbm9jaW5kZW50CnNldCBub3NtYXJ0aW5kZW50CnNldCBpbmRlbnRleHByJgoKIkhpZ2hsaWdodCBtYXRjaGluZyBicmFja2V0cwpzZXQgc2hvd21hdGNoCgoiQ2FzZSBpbnNlbnNpdGl2ZSBtYXRjaGluZyBpbiBzZWFyY2gKc2V0IGlnbm9yZWNhc2UKc2V0IHNtYXJ0Y2FzZQoiSGlnaGxpZ2h0IHNlYXJjaCBtYXRjaGVzCnNldCBobHNlYXJjaAoKIkFsbG93IHNlbGVjdGluZyB3aXRoIHRoZSBtb3VzZQpzZXQgbW91c2U9YQoKIlRoZSBmb2xsb3dpbmcgaXMgbm9ybWFsbHkgaW4gZGViaWFuLnZpbSBidXQgaXQgZG9lcyBub3QgZ2V0IHNvdXJjZWQgaWYgdmltcmMgZXhpc3RzCgpzZXQgbm9jb21wYXRpYmxlCSIgVXNlIFZpbSBkZWZhdWx0cyBpbnN0ZWFkIG9mIDEwMCUgdmkgY29tcGF0aWJpbGl0eQpzZXQgYmFja3NwYWNlPWluZGVudCxlb2wsc3RhcnQJIiBtb3JlIHBvd2VyZnVsIGJhY2tzcGFjaW5nCnNldCBoaXN0b3J5PTUwCQkiIGtlZXAgNTAgbGluZXMgb2YgY29tbWFuZCBsaW5lIGhpc3RvcnkKc2V0IHJ1bGVyCQkiIHNob3cgdGhlIGN1cnNvciBwb3NpdGlvbiBhbGwgdGhlIHRpbWUKc2V0IG5vbW9kZWxpbmUKIiBTdWZmaXhlcyB0aGF0IGdldCBsb3dlciBwcmlvcml0eSB3aGVuIGRvaW5nIHRhYiBjb21wbGV0aW9uIGZvciBmaWxlbmFtZXMuCiIgVGhlc2UgYXJlIGZpbGVzIHdlIGFyZSBub3QgbGlrZWx5IHRvIHdhbnQgdG8gZWRpdCBvciByZWFkLgpzZXQgc3VmZml4ZXM9LmJhayx+LC5zd3AsLm8sLmluZm8sLmF1eCwubG9nLC5kdmksLmJibCwuYmxnLC5icmYsLmNiLC5pbmQsLmlkeCwuaWxnLC5pbngsLm91dCwudG9jCgoiIFdlIGtub3cgeHRlcm0tZGViaWFuIGlzIGEgY29sb3IgdGVybWluYWwKaWYgJnRlcm0gPX4gInh0ZXJtLWRlYmlhbiIgfHwgJnRlcm0gPX4gInh0ZXJtLXhmcmVlODYiCiAgc2V0IHRfQ289MTYKICBzZXQgdF9TZj0bWzMlZG0KICBzZXQgdF9TYj0bWzQlZG0KZW5kaWYKCiIgU29tZSBEZWJpYW4tc3BlY2lmaWMgdGhpbmdzCmlmIGhhcygnZ3VpJykKICAiIE11c3QgZGVmaW5lIHRoaXMgd2l0aGluIHRoZSA6aWYgc28gaXQgZG9lcyBub3QgY2F1c2UgcHJvYmxlbXMgd2l0aAogICIgdmltLXRpbnkgKHdoaWNoIGRvZXMgbm90IGhhdmUgK2V2YWwpCiAgZnVuY3Rpb24hIDxTSUQ+TWFwRXhpc3RzKG5hbWUsIG1vZGVzKQogICAgZm9yIG1vZGUgaW4gc3BsaXQoYTptb2RlcywgJ1x6cycpCiAgICAgIGlmICFlbXB0eShtYXBhcmcoYTpuYW1lLCBtb2RlKSkKICAgICAgICByZXR1cm4gMQogICAgICBlbmRpZgogICAgZW5kZm9yCiAgICByZXR1cm4gMAogIGVuZGZ1bmN0aW9uCgogICIgTWFrZSBzaGlmdC1pbnNlcnQgd29yayBsaWtlIGluIFh0ZXJtCiAgYXV0b2NtZCBHVUlFbnRlciAqIGlmICE8U0lEPk1hcEV4aXN0cygiPFMtSW5zZXJ0PiIsICJudnNvIikgfCBleGVjdXRlICJtYXAgPFMtSW5zZXJ0PiA8TWlkZGxlTW91c2U+IiB8IGVuZGlmCiAgYXV0b2NtZCBHVUlFbnRlciAqIGlmICE8U0lEPk1hcEV4aXN0cygiPFMtSW5zZXJ0PiIsICJpYyIpIHwgZXhlY3V0ZSAibWFwISA8Uy1JbnNlcnQ+IDxNaWRkbGVNb3VzZT4iIHwgZW5kaWYKZW5kaWYKCiIgU2V0IHBhcGVyIHNpemUgZnJvbSAvZXRjL3BhcGVyc2l6ZSBpZiBhdmFpbGFibGUgKERlYmlhbi1zcGVjaWZpYykKaWYgZmlsZXJlYWRhYmxlKCIvZXRjL3BhcGVyc2l6ZSIpCiAgbGV0IHM6cGFwZXJzaXplID0gbWF0Y2hzdHIocmVhZGZpbGUoJy9ldGMvcGFwZXJzaXplJywgJycsIDEpLCAnXHAqJykKICBpZiBzdHJsZW4oczpwYXBlcnNpemUpCiAgICBleGUgInNldCBwcmludG9wdGlvbnMrPXBhcGVyOiIgLiBzOnBhcGVyc2l6ZQogIGVuZGlmCmVuZGlmCg==' | base64 -d > "$HOME/.vimrc"
    echo '[.bashrc] Added .vimrc'
fi

#Mitigate supply chain attacks: don't install package versions released less than 52 days ago (most malicious versions are detected and removed by then), and don't run install scripts
if [[ -z $MSYSTEM ]]; then
    #If the config file already exists, use the program to edit it, keeping the other settings (eg auth tokens)
    #The global npm config is usually only writable by root. For pnpm, --location=global is the config of the current user
    if [[ -f "$HOME/.npmrc" ]] && [[ $(stat -c %Y "$HOME/.npmrc") -ge 1793199795 ]]; then
        : # Already up to date
    elif ! command -v 'npm' >/dev/null; then
        : # npm is not installed
    elif [[ -f "$HOME/.npmrc" ]]; then
        { npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=user; } && { [[ $EUID -ne 0 ]] || npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=global; } && echo '[.bashrc] Set npm security settings'
    else
        mkdir -p "$(dirname "$HOME/.npmrc")"
        echo 'IyBEb24ndCBpbnN0YWxsIHBhY2thZ2UgdmVyc2lvbnMgcmVsZWFzZWQgbGVzcyB0aGFuIDUyIGRheXMgYWdvLiBOZWVkcyBucG0gMTEuMTArLCBvbGRlciB2ZXJzaW9ucyBkaXNwbGF5IGEgd2FybmluZwptaW4tcmVsZWFzZS1hZ2U9NTIKaWdub3JlLXNjcmlwdHM9dHJ1ZQojIEdpdCBkZXBlbmRlbmNpZXMgYnlwYXNzIHRoZSByZWdpc3RyeSwgc28gbWluLXJlbGVhc2UtYWdlIGRvZXMgbm90IGFwcGx5IHRvIHRoZW0uIERlZmF1bHQgaW4gbnBtIDEyCmFsbG93LWdpdD1ub25lCg==' | base64 -d > "$HOME/.npmrc"
        echo '[.bashrc] Set npm security settings'
    fi
    #pnpm 11+ reads its settings from config.yaml instead of rc. If config.yaml does not exist, pnpm 10 is presumably installed, so set the settings in rc with the commands
    #config.yaml is still written, so that the commands are not run again and pnpm is configured once upgraded
    if command -v pnpm >/dev/null; then
        if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" ]] && [[ $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml") -ge 1793199796 ]]; then
            : # Already up to date
        elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" ]]; then
            { pnpm config set minimumReleaseAge 74880 --location=global; } && { pnpm config set ignoreScripts true --location=global; } && { pnpm config set trustPolicy no-downgrade --location=global; } && echo '[.bashrc] Set pnpm security settings'
        else
            if { pnpm config set minimum-release-age 74880 --location=global; } && { pnpm config set trust-policy no-downgrade --location=global; } && { pnpm config set block-exotic-subdeps true --location=global; }; then
                mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml")"
                echo 'IyBEb24ndCBpbnN0YWxsIHBhY2thZ2UgdmVyc2lvbnMgcmVsZWFzZWQgbGVzcyB0aGFuIDUyIGRheXMgYWdvIChpbiBtaW51dGVzKQptaW5pbXVtUmVsZWFzZUFnZTogNzQ4ODAKaWdub3JlU2NyaXB0czogdHJ1ZQojIEZhaWwgaWYgYSBwYWNrYWdlIHZlcnNpb24gaXMgcHVibGlzaGVkIHdpdGggbGVzcyB0cnVzdCBldmlkZW5jZSAoZWcgd2l0aG91dCBwcm92ZW5hbmNlKSB0aGFuIHRoZSBwcmV2aW91cyB2ZXJzaW9ucywgd2hpY2ggaXMgdHlwaWNhbCBvZiBzdG9sZW4gdG9rZW5zCnRydXN0UG9saWN5OiBuby1kb3duZ3JhZGUK' | base64 -d > "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml"
                echo '[.bashrc] Set pnpm security settings'
            fi
        fi
    fi
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml" ]] && [[ $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml") -ge 1793199799 ]]; then
        : # Already up to date
    elif ! command -v 'uv' >/dev/null; then
        : # uv is not installed
    else
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml")"
        echo 'IyBEb24ndCBpbnN0YWxsIHBhY2thZ2UgdmVyc2lvbnMgcmVsZWFzZWQgbGVzcyB0aGFuIDUyIGRheXMgYWdvLiBOZWVkcyB1diAwLjkuMTcrLCBvbGRlciB2ZXJzaW9ucyBmYWlsIHRvIHBhcnNlIHRoZSBkdXJhdGlvbgpleGNsdWRlLW5ld2VyID0gIjUyIGRheXMiCiMgQnVpbGRpbmcgc291cmNlIGRpc3RyaWJ1dGlvbnMgcnVucyBhcmJpdHJhcnkgY29kZS4gVXNlIC0tbm8tY29uZmlnIHRvIGluc3RhbGwgYSBwYWNrYWdlIHRoYXQgaGFzIG5vIHdoZWVscwpuby1idWlsZCA9IHRydWUK' | base64 -d > "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml"
        echo '[.bashrc] Set uv security settings'
    fi
    if [[ -f "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml" ]] && [[ $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml") -ge 1793199804 ]]; then
        : # Already up to date
    elif ! command -v 'bun' >/dev/null; then
        : # bun is not installed
    else
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml")"
        echo 'W2luc3RhbGxdCiMgRG9uJ3QgaW5zdGFsbCBwYWNrYWdlIHZlcnNpb25zIHJlbGVhc2VkIGxlc3MgdGhhbiA1MiBkYXlzIGFnbyAoaW4gc2Vjb25kcykKbWluaW11bVJlbGVhc2VBZ2UgPSA0NDkyODAwCmlnbm9yZVNjcmlwdHMgPSB0cnVlCg==' | base64 -d > "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml"
        echo '[.bashrc] Set bun security settings'
    fi
fi
