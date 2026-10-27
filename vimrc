"Note: this is automatically generated and overwritten by .bashrc

" Reopen the last edited position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
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
  set t_Sf=[3%dm
  set t_Sb=[4%dm
endif

" Some Debian-specific things
if has('gui')
  " Must define this within the :if so it does not cause problems with
  " vim-tiny (which does not have +eval)
  function! <SID>MapExists(name, modes)
    for mode in split(a:modes, '\zs')
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
  let s:papersize = matchstr(readfile('/etc/papersize', '', 1), '\p*')
  if strlen(s:papersize)
    exe "set printoptions+=paper:" . s:papersize
  endif
endif
