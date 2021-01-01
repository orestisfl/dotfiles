call plug#begin('~/.local/share/nvim/plugged')

Plug 'https://github.com/scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

let $FZF_DEFAULT_COMMAND = 'fd --type f'
source /usr/share/vim/vimfiles/plugin/fzf.vim
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/tweekmonster/fzf-filemru'

Plug 'https://github.com/tpope/vim-surround'
" 's' is not that useful: bind it to vim-surround
xmap s <Plug>VSurround

" highlight whitespace errors + cleanup functions
Plug 'https://github.com/ntpeters/vim-better-whitespace'

" gcc -> toggle comments
Plug 'https://github.com/tpope/vim-commentary'
" For git
Plug 'https://github.com/tpope/vim-fugitive'

source ~/.config/nvim/coc.vim

" manages tag files - automatically creates
Plug 'https://github.com/ludovicchabant/vim-gutentags', { 'for': ['c', 'python', 'java'] }
let g:gutentags_file_list_command = 'rg --files'
Plug 'https://github.com/octol/vim-cpp-enhanced-highlight', { 'for': ['c', 'cpp'] }
Plug 'https://github.com/pangloss/vim-javascript', { 'for': ['c', 'javascript'] }
" Display these tags
Plug 'https://github.com/majutsushi/tagbar', { 'on': 'TagbarToggle' }

" Asynchronous linting and make framework for Neovim/Vim
" Plug 'https://github.com/neomake/neomake'

" Haskell
Plug 'https://github.com/neovimhaskell/haskell-vim'

" close buffer without closing windows
Plug 'https://github.com/moll/vim-bbye'

" Theme
Plug 'https://github.com/morhetz/gruvbox'

call plug#end()
