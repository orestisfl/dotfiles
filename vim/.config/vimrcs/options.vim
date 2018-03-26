" --------------------------------------------------
" ------------------ Appearance --------------------
" --------------------------------------------------
" Terminal colors for theme etc.
set background=dark

" Enable syntax highlighting.
syntax enable

set ruler  " Always show current position.
set scrolloff=7  " Set 7 lines to the cursor - when moving vertically using j/k.
set number  " Both number & relativenumber => hybrid mode
set relativenumber

set noshowmode
set showcmd

" Highlight current line.
set cursorline

" Always display the status line.
set laststatus=2

if &t_Co >= 256
    " Set the colorscheme of vim & lightline.
    colorscheme Tomorrow-Night-Eighties
    let g:lightline = {'colorscheme': 'Tomorrow_Night_Eighties'}

    " vimdiff colors
    " https://stackoverflow.com/a/17183382/3430986
    highlight DiffAdd    cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
    highlight DiffDelete cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
    highlight DiffChange cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
    highlight DiffText   cterm=bold ctermfg=10 ctermbg=88 gui=none guifg=bg guibg=Red

    hi CursorLine term=bold cterm=bold guibg=Grey40

    " Popup menu colors.
    highlight Pmenu ctermfg=15 ctermbg=0 guifg=#ffffff guibg=#000000

    " Switch from block-cursor to vertical-line-cursor when going into/out of insert mode.
    let &t_EI = "\033[1 q"
    let &t_SI = "\033[5 q"
endif

set conceallevel=0


" --------------------------------------------------
" ------------------ Searching ---------------------
" --------------------------------------------------
set ignorecase  " Ignore case when searching.
set smartcase  " When searching try to be smart about cases.
set hlsearch  " Highlight search results.
set incsearch  " Show current matching result while typing.
set magic  " For regular expressions.
" Set highlighting colors.
hi Search cterm=NONE ctermfg=White ctermbg=Blue

" This unsets the 'last search pattern' register by hitting return.
nnoremap <CR> :noh<CR><CR>


" --------------------------------------------------
" ---------------- Other settings ------------------
" --------------------------------------------------
set omnifunc=syntaxcomplete#Complete

set splitright  " Split window to the right of current one.

" Trim trailing whitespace for these filetypes:
autocmd FileType c,cpp,python,ruby,java autocmd BufWritePre <buffer> :%s/\s\+$//e

" Instead of failing a command because of unsaved changes, raise a confirmation dialog.
set confirm

" http://www.johnhawthorn.com/2012/09/vi-escape-delays/
set timeoutlen=1000 ttimeoutlen=0

" This allows buffers to be hidden if you've modified a buffer.
" This is almost a must if you wish to use buffers in this way.
set hidden

" Sets how many lines of history VIM has to remember.
set history=500

" Set to auto read when a file is changed from the outside.
set autoread

" Persistent undo.
set undodir='$HOME/.cache/vim-undodir'
set undofile
call system('mkdir -p ' . &undodir)

" Disable auto-comment on newlines.
" http://superuser.com/a/271024/253307
" http://vim.wikia.com/wiki/Disable_automatic_comment_insertion#Disabling_in_general
autocmd FileType * setlocal formatoptions-=cro

set wildmenu
set wildmode=list:longest,full

" Ignore compiled files.
set wildignore=*.o,*~,*.pyc
if has("win16") || has("win32")
    set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store
else
    set wildignore+=.git\*,.hg\*,.svn\*
endif

" Configure backspace so it acts as it should act.
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

" Don't redraw while executing macros (good performance config).
set lazyredraw

" Show matching brackets when text indicator is over them.
set showmatch
" How many tenths of a second to blink when matching brackets.
set mat=2

" No annoying sound on errors.
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8

" Use Unix as the standard file type
set ffs=unix,mac,dos

" Turn backup off, since most stuff is in SVN, git etc anyway.
set nobackup
set nowb
set noswapfile

" 1 tab == 4 spaces.
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
" Correct tab for Makefiles.
autocmd FileType make set noexpandtab shiftwidth=4 softtabstop=0

set ai  " Auto indent.
set si  " Smart indent.
set nowrap " Don't wrap long lines.
