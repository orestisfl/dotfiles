" from fzf - fuzzy search through buffers
nnoremap <Leader>bB :Buffers<CR>
" from fzf - fuzzy search through buffers + history
nnoremap <Leader>bb :History<CR>
" from vim-bbye - delete buffer without closing window
nnoremap <Leader>bd :Bdelete<CR>

" from fzf - fuzzy search through project files
nnoremap <Leader>pf :Files<CR>

" from fzf - fuzzy search through commands
nnoremap <Leader><Leader> :Commands<CR>

nnoremap <Leader>tt :TagbarToggle<CR>

" Stop the highlighting for the 'hlsearch' option. It is automatically turned back on when using a
" search command
nnoremap <CR> :nohlsearch<CR><CR>

" Emacs-like bindings in the command line from `:h emacs-keys`
cnoremap <C-a>  <Home>
cnoremap <C-b>  <Left>
cnoremap <C-f>  <Right>
cnoremap <C-d>  <Del>
cnoremap <C-e>  <End>
cnoremap <M-b>  <S-Left>
cnoremap <M-f>  <S-Right>
cnoremap <M-d>  <S-right><Delete>
cnoremap <C-g> <C-c>

noremap Y y$

set notimeout
