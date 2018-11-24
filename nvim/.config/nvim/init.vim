set number relativenumber
set foldlevelstart=6

" Use the system clipboard
set clipboard+=unnamedplus

" Use , as the leader key
let mapleader=" "

" Enable mouse mode
" set mouse=a

" #4684: skip nvim's auto-enable logic
filetype plugin indent on
" Don't autocomment next line on 'o' or enter.
autocmd FileType * setlocal formatoptions-=ro
set textwidth=100

source ~/.config/nvim/plugins.vim
source ~/.config/nvim/maps.vim
"set termguicolors
set background=dark
colorscheme gruvbox

set smartcase
" https://vi.stackexchange.com/a/11222/
set inccommand=nosplit

" When off a buffer is unloaded when it is abandoned. When on a buffer becomes
" hidden when it is abandoned.
set hidden

" Turn backup off
set nobackup
set nowb
set noswapfile

" Use whole words when opening URLs.
" This avoids cutting off parameters (after '?') and anchors (after '#').
" http://vi.stackexchange.com/q/2801/1631
let g:netrw_gx="<cWORD>"

" Have Vim jump to the last position when reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif
