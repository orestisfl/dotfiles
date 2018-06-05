set smartcase
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

" Turn backup off
set nobackup
set nowb
set noswapfile

" Have Vim jump to the last position when reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif
