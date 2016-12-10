set foldlevelstart=6


set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" Press v over and over again to expand selection
Plugin 'terryma/vim-expand-region'
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

Plugin 'haya14busa/incsearch.vim'
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

let g:ycm_path_to_python_interpreter = '/usr/bin/python3'
Plugin 'Valloric/YouCompleteMe'
Plugin 'rdnetto/YCM-Generator'
"Plugin 'vim-scripts/a.vim' imaps stuff to <leader>
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'

Plugin 'scrooloose/syntastic'
Plugin 'mhinz/vim-startify'
Plugin 'The-NERD-Commenter'
Plugin 'scrooloose/nerdtree'
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'Yggdroot/indentLine'
Plugin 'airblade/vim-gitgutter'
Plugin 'tpope/vim-fugitive'
let g:gitgutter_map_keys = 0  " Disable all mappings for gitgutter.

Plugin 'flazz/vim-colorschemes'
Plugin 'itchyny/lightline.vim'

Plugin 'ntpeters/vim-better-whitespace'
Plugin 'Raimondi/delimitMate'

Plugin 'ctrlpvim/ctrlp.vim'
let g:ctrlp_cmd = 'CtrlPMixed'

Plugin 'PotatoesMaster/i3-vim-syntax'
Plugin 'vim-scripts/indentpython.vim'
" Better folding for python code
Plugin 'tmhedberg/SimpylFold'
let g:SimpylFold_docstring_preview = 1
let g:SimpylFold_fold_docstring = 0
autocmd BufWinEnter *.py setlocal foldexpr=SimpylFold(v:lnum) foldmethod=expr
autocmd BufWinLeave *.py setlocal foldexpr< foldmethod<

Plugin 'suan/vim-instant-markdown'

Plugin 'xolox/vim-misc'
Plugin 'xolox/vim-easytags'
Plugin 'majutsushi/tagbar'

" https://github.com/jez/vim-as-an-ide/commit/7b698e2
Plugin 'christoomey/vim-tmux-navigator'

call vundle#end()            " required
filetype plugin indent on    " required
set omnifunc=syntaxcomplete#Complete

" Instead of failing a command because of unsaved changes, instead raise
" dialogue asking if you wish to save changed files.
set confirm

" Terminal colors for theme etc.
set t_Co=256
" display numbers
set nu
set background=dark

" Highlight current line.
set cursorline
hi CursorLine term=bold cterm=bold guibg=Grey40

" Switch from block-cursor to vertical-line-cursor when going into/out of insert mode
let &t_EI = "\033[1 q"
let &t_SI = "\033[5 q"

" http://www.johnhawthorn.com/2012/09/vi-escape-delays/
set timeoutlen=1000 ttimeoutlen=0

highlight Pmenu ctermfg=15 ctermbg=0 guifg=#ffffff guibg=#000000

" set fillchars+=stl:\ ,stlnc:\
set laststatus=2

" This allows buffers to be hidden if you've modified a buffer.
" This is almost a must if you wish to use buffers in this way.
set hidden

set noshowmode
set showcmd

" Sets how many lines of history VIM has to remember
set history=500

" Set to auto read when a file is changed from the outside
set autoread

" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
"let mapleader = ","
let g:mapleader = "\<Space>"
let mapleader = "\<Space>"

" Open buffer
nnoremap <leader>b :ls<cr>:b<space>

" To open a new empty buffer
nmap <leader>t :enew<cr>

" Save file
nnoremap <Leader>w :w<CR>

" Toggle comment
nnoremap <Leader>e :call NERDComment(0, "toggle")<C-m>

" ----- jistr/vim-nerdtree-tabs -----
nmap <silent> <Leader>ss :NERDTreeTabsToggle<CR>
" To have NERDTree always open on startup
"let g:nerdtree_tabs_open_on_console_startup = 1

" ----- xolox/vim-easytags settings -----
" Where to look for tags files
set tags=./tags;,~/.vimtags
" Sensible defaults
let g:easytags_events = ['BufReadPost', 'BufWritePost']
let g:easytags_async = 1
let g:easytags_dynamic_files = 2
let g:easytags_resolve_links = 1
let g:easytags_suppress_ctags_warning = 1

" ----- majutsushi/tagbar settings -----
nmap <silent> <leader>st :TagbarToggle<CR>
" Uncomment to open tagbar automatically whenever possible
"autocmd BufEnter * nested :call tagbar#autoopen(0)

" Disable auto-comment o newlines
" http://superuser.com/a/271024/253307
" http://vim.wikia.com/wiki/Disable_automatic_comment_insertion#Disabling_in_general
autocmd FileType * setlocal formatoptions-=cro

" :W sudo saves the file
" (useful for handling the permission-denied error)
"command W w !sudo tee % > /dev/null

" Set 7 lines to the cursor - when moving vertically using j/k
set scrolloff=7

set wildmenu
set wildmode=list:longest,full

" Ignore compiled files
set wildignore=*.o,*~,*.pyc
if has("win16") || has("win32")
    set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store
else
    set wildignore+=.git\*,.hg\*,.svn\*
endif

"Always show current position
set ruler

" Configure backspace so it acts as it should act
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch
hi Search cterm=NONE ctermfg=White ctermbg=Blue

" This unsets the 'last search pattern' register by hitting return
nnoremap <CR> :noh<CR><CR>

" Makes search act like search in modern browsers
set incsearch

" Don't redraw while executing macros (good performance config)
set lazyredraw

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch
" How many tenths of a second to blink when matching brackets
set mat=2

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Enable syntax highlighting
syntax enable

" http://stackoverflow.com/a/21434697/3430986
" Disabled Syntastic by default and activate/disable error checking with the following:
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
nnoremap <leader>sc :SyntasticCheck<CR> :SyntasticToggleMode<CR>

" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8

" Use Unix as the standard file type
set ffs=unix,mac,dos

" Turn backup off, since most stuff is in SVN, git etc anyway.
set nobackup
set nowb
set noswapfile

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines

" Visual mode pressing * or # searches for the current selection
" Super useful! From an idea by Michael Naumann
vnoremap <silent> * :call VisualSelection('f', '')<CR>
vnoremap <silent> # :call VisualSelection('b', '')<CR>

" Treat long lines as break lines (useful when moving around in them)
map j gj
map k gk

" Remap VIM 0 to first non-blank character
map 0 ^

" Move a line of text using ALT+[jk] or Comamnd+[jk] on mac
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

" Split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-Down> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-Up> <C-W><C-K>
nnoremap <C-Right> <C-W><C-L>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-Left> <C-W><C-H>
nnoremap <C-H> <C-W><C-H>

set splitbelow
set splitright

"python with virtualenv support
py << EOF
import os
import sys
if 'VIRTUAL_ENV' in os.environ:
  project_base_dir = os.environ['VIRTUAL_ENV']
  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
  execfile(activate_this, dict(__file__=activate_this))
EOF

" Delete trailing white space on save, useful for Python etc..
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc

" Trim trailing whitespace
autocmd BufWrite *.c :call DeleteTrailingWS()
autocmd BufWrite *.py :call DeleteTrailingWS()

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
if !exists(":DiffOrig")
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis
          \ | wincmd p | diffthis
endif

function! CmdLine(str)
    exe "menu Foo.Bar :" . a:str
    emenu Foo.Bar
    unmenu Foo
endfunction

function! VisualSelection(direction, extra_filter) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", '\\/.*$^~[]')
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'b'
        execute "normal ?" . l:pattern . "^M"
    elseif a:direction == 'gv'
        call CmdLine("Ag \"" . l:pattern . "\" " )
    elseif a:direction == 'replace'
        call CmdLine("%s" . '/'. l:pattern . '/')
    elseif a:direction == 'f'
        execute "normal /" . l:pattern . "^M"
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction


" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    endif
    return ''
endfunction

" Don't close window, when deleting a buffer
command! Bclose call <SID>BufcloseCloseIt()
function! <SID>BufcloseCloseIt()
   let l:currentBufNum = bufnr("%")
   let l:alternateBufNum = bufnr("#")

   if buflisted(l:alternateBufNum)
     buffer #
   else
     bnext
   endif

   if bufnr("%") == l:currentBufNum
     new
   endif

   if buflisted(l:currentBufNum)
     execute("bdelete! ".l:currentBufNum)
   endif
endfunction
