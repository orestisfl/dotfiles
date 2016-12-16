set foldlevelstart=6


set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" Visually select increasingly larger regions of text using the same key combination.
Plugin 'terryma/vim-expand-region'
" Improved incremental searching.
Plugin 'haya14busa/incsearch.vim'
" A code-completion engine.
Plugin 'Valloric/YouCompleteMe'
" Generates config files for YouCompleteMe
Plugin 'rdnetto/YCM-Generator'
" fzf + vim.
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'
" Syntax checking hacks.
Plugin 'scrooloose/syntastic'
" Fancy start screen.
Plugin 'mhinz/vim-startify'
" For toggling comment lines.
Plugin 'The-NERD-Commenter'
" Tree explorer.
Plugin 'scrooloose/nerdtree'
" A plugin of NERDTree showing git status.
Plugin 'Xuyuanp/nerdtree-git-plugin'
" Display the indention levels with thin vertical lines.
Plugin 'Yggdroot/indentLine'
" Shows a git diff in the gutter (sign column) and stages/undoes hunks.
Plugin 'airblade/vim-gitgutter'
" Git wrapper.
Plugin 'tpope/vim-fugitive'
" Big colorscheme pack.
Plugin 'flazz/vim-colorschemes'
" A light and configurable statusline/tabline for Vim.
Plugin 'itchyny/lightline.vim'
" Better whitespace highlighting for Vim.
Plugin 'ntpeters/vim-better-whitespace'
" Provides insert mode auto-completion for quotes, parens, brackets, etc.
Plugin 'Raimondi/delimitMate'
" Fuzzy file, buffer, mru, tag, etc finder.
Plugin 'ctrlpvim/ctrlp.vim'
" Syntax for i3 window manager config.
Plugin 'PotatoesMaster/i3-vim-syntax'
" An alternative indentation script for python.
Plugin 'vim-scripts/indentpython.vim'
" Better folding for python code
Plugin 'tmhedberg/SimpylFold'
" Instant Markdown previews.
Plugin 'suan/vim-instant-markdown'
" Miscellaneous auto-load Vim scripts.
Plugin 'xolox/vim-misc'
" Automated tag file generation and syntax highlighting of tags.
Plugin 'xolox/vim-easytags'
" Displays tags in a window, ordered by scope.
Plugin 'majutsushi/tagbar'
" Seamless navigation between tmux panes and vim splits.
" https://github.com/jez/vim-as-an-ide/commit/7b698e2
Plugin 'christoomey/vim-tmux-navigator'

call vundle#end()            " required
filetype plugin indent on    " required
