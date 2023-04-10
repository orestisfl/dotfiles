set clipboard+=unnamedplus
set nu
set mouse+=a

set inccommand=nosplit

set ignorecase
set smartcase

set scrolloff=10

" Have Vim jump to the last position when reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif

set ts=4 sw=4 expandtab

let mapleader=" "
let maplocalleader = ","

let $NVIM_TUI_ENABLE_TRUE_COLOR=1
let $FZF_DEFAULT_OPTS = '--bind alt-a:select-all,alt-d:deselect-all'

set background=dark
autocmd vimenter * ++nested colorscheme gruvbox

call plug#begin('~/.local/share/nvim/plugged')

Plug 'https://github.com/williamboman/mason.nvim'
Plug 'https://github.com/williamboman/mason-lspconfig.nvim'
Plug 'https://github.com/neovim/nvim-lspconfig'

" close buffer without closing windows
Plug 'https://github.com/moll/vim-bbye'

" Theme
Plug 'https://github.com/morhetz/gruvbox'

" gcc -> toggle comments
Plug 'https://github.com/tpope/vim-commentary'
" For git
Plug 'https://github.com/tpope/vim-fugitive'
command! Gbrowse GBrowse
" Plug 'https://github.com/shumphrey/fugitive-gitlab.vim'
Plug 'https://github.com/tpope/vim-rhubarb'
let g:fugitive_gitlab_domains = ['https://gitlab.ppro.com']

Plug 'https://github.com/tpope/vim-surround'
" 's' is not that useful: bind it to vim-surround
xmap s <Plug>VSurround

Plug 'https://github.com/junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'https://github.com/junegunn/fzf.vim'

Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
let g:go_fmt_autosave = 0
let g:go_imports_autosave = 0

call plug#end()

set completeopt=menu,menuone,noselect

luafile ~/.config/nvim/lua.lua

nnoremap <Leader>w :w<CR>
noremap Y y$

nnoremap <Leader>q :bd<CR>
nnoremap <Leader>f :Files<CR>
nnoremap <Leader>b :Buffers<CR>

nnoremap <CR> :nohlsearch<CR><CR>

silent !mkdir -p /tmp/vim-undo /tmp/vim-backup /tmp/vim-swp &>/dev/null
set undodir=/tmp/vim-undo//
set backupdir=/tmp/vim-backup//
set directory=/tmp/vim-swp//

let g:netrw_browsex_viewer= "xdg-open"
