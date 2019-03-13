" from fzf - fuzzy search through buffers
nnoremap <Leader>bB :Buffers<CR>
nnoremap <Leader>B :Buffers<CR>
" from fzf - fuzzy search through buffers + history
nnoremap <Leader>bb :History<CR>
" from vim-bbye - delete buffer without closing window
nnoremap <Leader>bd :Bdelete<CR>

" from fzf - fuzzy search through project files
nnoremap <c-p> :ProjectMru --tiebreak=end<cr>
nnoremap <Leader>pf :ProjectMru --tiebreak=end<cr>

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

function SetLSPShortcuts()
  nnoremap <leader>ld :call LanguageClient#textDocument_definition()<CR>
  nnoremap <leader>lr :call LanguageClient#textDocument_rename()<CR>
  nnoremap <leader>lf :call LanguageClient#textDocument_formatting()<CR>
  nnoremap <leader>lt :call LanguageClient#textDocument_typeDefinition()<CR>
  nnoremap <leader>lx :call LanguageClient#textDocument_references()<CR>
  nnoremap <leader>la :call LanguageClient_workspace_applyEdit()<CR>
  nnoremap <leader>lc :call LanguageClient#textDocument_completion()<CR>
  nnoremap <leader>lh :call LanguageClient#textDocument_hover()<CR>
  nnoremap <leader>ls :call LanguageClient_textDocument_documentSymbol()<CR>
endfunction()

augroup LSP
  autocmd!
  autocmd FileType cpp,c call SetLSPShortcuts()
augroup END

nnoremap <F5> :call LanguageClient_contextMenu()<CR>
