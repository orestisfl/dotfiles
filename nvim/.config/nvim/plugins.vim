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

" source ~/.config/nvim/plugins/LC.vim
source ~/.config/nvim/plugins/coc.vim

" manages tag files - automatically creates
Plug 'https://github.com/ludovicchabant/vim-gutentags', { 'for': ['c', 'python', 'java'] }
let g:gutentags_file_list_command = 'rg --files'
Plug 'https://github.com/octol/vim-cpp-enhanced-highlight', { 'for': ['c', 'cpp'] }
Plug 'https://github.com/pangloss/vim-javascript', { 'for': ['c', 'javascript'] }
" Display these tags
Plug 'https://github.com/majutsushi/tagbar', { 'on': 'TagbarToggle' }

" latex
Plug 'https://github.com/lervag/vimtex'
" I can access the quickfix window with :cw
" Either automatically close vimtex's quickfix window after X keystrokes or
" don't open it on warnings.
" let g:vimtex_quickfix_autoclose_after_keystrokes = 4
let g:vimtex_quickfix_open_on_warning = 0
" Uses https://github.com/stefanhepp/pplatex to parse the LaTeX output file.
" pplatex is a command line utility used to pretify the output of the LaTeX
" compiler.
let g:vimtex_quickfix_method = 'pplatex'
" Default imaps mapping interferes with ``'' quotes.
" https://github.com/lervag/vimtex/issues/325
let g:vimtex_imaps_leader = ';'

" Asynchronous linting and make framework for Neovim/Vim
" Plug 'https://github.com/neomake/neomake'

" close buffer without closing windows
Plug 'https://github.com/moll/vim-bbye'

" Code formaters
Plug 'https://github.com/w0rp/ale', { 'on': 'ALEEnable' }
let g:ale_lint_on_enter = 0
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_save = 0
let g:ale_fixers = {'c': ['clang-format'], 'python': ['black']}
let g:ale_linters = {'sh': ['shellcheck']}
" Python code formatter
Plug 'https://github.com/ambv/black', { 'for': 'python' }
let g:black_virtualenv = '~/.local/share/nvim/black'

" TODO:
" Plug 'https://github.com/Shougo/denite.nvim'
" Plug 'https://github.com/neomake/neomake'
" Plug 'https://github.com/Raimondi/delimitMate'  " for automatic closing
" Plug 'https://github.com/easymotion/vim-easymotion'  " simpler way to use some motions in vim
" Plug 'https://github.com/osyo-manga/vim-over'  " :substitute preview

" Theme
Plug 'https://github.com/morhetz/gruvbox'

call plug#end()
