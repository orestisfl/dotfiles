call plug#begin('~/.local/share/nvim/plugged')

Plug 'https://github.com/scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

source /usr/share/vim/vimfiles/plugin/fzf.vim
Plug 'https://github.com/junegunn/fzf.vim'

Plug 'https://github.com/tpope/vim-surround'
" 's' is not that useful: bind it to vim-surround
xmap s <Plug>VSurround

" highlight whitespace errors + cleanup functions
Plug 'https://github.com/ntpeters/vim-better-whitespace'

" gcc -> toggle comments
Plug 'https://github.com/tpope/vim-commentary'
Plug 'https://github.com/tpope/vim-fugitive'

" For completion
Plug 'https://github.com/Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
let g:deoplete#enable_at_startup = 1

Plug 'https://github.com/autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }
" For clangd info:
" https://github.com/autozimu/LanguageClient-neovim/wiki/Clangd
let g:LanguageClient_serverCommands = {
    \ 'c': ['ccls'],
    \ 'cpp': ['ccls'],
    \ 'python': ['pyls'],
    \ }
nnoremap <F5> :call LanguageClient_contextMenu()<CR>
" handle the function signatures displaying
Plug 'Shougo/echodoc.vim'
set cmdheight=2
let g:echodoc#enable_at_startup = 1
let g:echodoc#type = 'signature'

" manages tag files - automatically creates
Plug 'https://github.com/ludovicchabant/vim-gutentags', { 'for': ['c', 'python'] }
Plug 'https://github.com/octol/vim-cpp-enhanced-highlight', { 'for': ['c', 'cpp'] }
Plug 'https://github.com/majutsushi/tagbar', { 'on': 'TagbarToggle' }

" Plug 'https://github.com/Shougo/neoinclude.vim'  " include/header files completion
" Plug 'https://github.com/zchee/deoplete-jedi' " Python
" Plug 'https://github.com/sebastianmarkow/deoplete-rust'
" Plug 'https://github.com/SevereOverfl0w/deoplete-github'  " github issues # autocompletion

" latex
Plug 'https://github.com/lervag/vimtex'
" Vim syntax for i3 window manager config
Plug 'https://github.com/PotatoesMaster/i3-vim-syntax'

" Instant Markdown previews
Plug 'https://github.com/suan/vim-instant-markdown', { 'for': 'markdown' }

" Asynchronous linting and make framework for Neovim/Vim
" Plug 'https://github.com/neomake/neomake'

" close buffer without closing windows
Plug 'https://github.com/moll/vim-bbye'

" automatic keyboard layout switching in insert mode
Plug 'https://github.com/lyokha/vim-xkbswitch'
let g:XkbSwitchEnabled = 1

" Code formaters
Plug 'https://github.com/w0rp/ale', { 'on': 'ALEEnable' }
let g:ale_lint_on_enter = 0
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_save = 0
let g:ale_fixers = {'c': ['clang-format'], 'python': ['black']}
" Python code formatter
Plug 'https://github.com/ambv/black', { 'for': 'python' }

" TODO:
" Plug 'https://github.com/Shougo/denite.nvim'
" Plug 'https://github.com/neomake/neomake'
" Plug 'https://github.com/editorconfig/editorconfig-vim'
" Plug 'https://github.com/Raimondi/delimitMate'  " for automatic closing
" Plug 'https://github.com/easymotion/vim-easymotion'  " simpler way to use some motions in vim
" Plug 'https://github.com/osyo-manga/vim-over'  " :substitute preview
" Plug 'https://github.com/tpope/vim-markdown', { 'for': 'markdown' }

" Other C stuff:
" Plug 'https://github.com/arakashic/chromatica.nvim', { 'do': ':UpdateRemotePlugins' }
" let g:chromatica#enable_at_startup=1
" Clang based syntax highlighting for Neovim
" Plug 'https://github.com/bbchung/Clamp'
" let g:clamp_autostart = 1
" let g:clamp_highlight_mode = 1

" Theme
Plug 'https://github.com/morhetz/gruvbox'

call plug#end()

" Alternatives for completion etc:
" Using rtags:
" Plug 'https://github.com/lyuts/vim-rtags', { 'for': ['c', 'cpp'] }
" Plug 'https://github.com/marxin/neo-rtags', { 'for': ['c', 'cpp'], 'do': ':UpdateRemotePlugins' }
" ncm2:
" Plug 'https://github.com/ncm2/ncm2'
" " enable ncm2 for all buffers
" autocmd BufEnter * call ncm2#enable_for_buffer()
" " IMPORTANTE: :help Ncm2PopupOpen for more information
" set completeopt=noinsert,menuone,noselect
" Plug 'https://github.com/ncm2/ncm2-pyclang'
" " let g:ncm2_pyclang#library_path = '/usr/lib/libclang.so'
" " a list of relative paths for compile_commands.json
" let g:ncm2_pyclang#database_path = [
"             \ 'compile_commands.json',
"             \ 'build/compile_commands.json'
"             \ ]
" deoplete:
" Plug 'https://github.com/Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
" let g:deoplete#enable_at_startup = 1
" Plug 'https://github.com/zchee/deoplete-clang', { 'for': ['c', 'cpp'] }
" or
" Plug 'https://github.com/tweekmonster/deoplete-clang2', { 'for': ['c', 'cpp'] }
" let g:deoplete#sources#clang#libclang_path = "/usr/lib/libclang.so"
" let g:deoplete#sources#clang#clang_header = "/usr/include/clang/"
" LanguageClient with clangd:
    " \ 'c': ['clangd'],
    " \ 'cpp': ['clangd'],
