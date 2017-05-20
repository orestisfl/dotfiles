" --------------------------------------------------
" ----------------- SimplylFold --------------------
" --------------------------------------------------
let g:SimpylFold_docstring_preview = 1
let g:SimpylFold_fold_docstring = 0
autocmd BufWinEnter *.py setlocal foldexpr=SimpylFold(v:lnum) foldmethod=expr
autocmd BufWinLeave *.py setlocal foldexpr< foldmethod<


" --------------------------------------------------
" ------------------ Syntastic ---------------------
" --------------------------------------------------
" http://stackoverflow.com/a/21434697/3430986
" Disable Syntastic by default and activate/disable error checking with the following:
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
nnoremap <leader>sc :SyntasticCheck<CR> :SyntasticToggleMode<CR>


" --------------------------------------------------
" ------------------- tagbar -----------------------
" --------------------------------------------------
nmap <silent> <leader>st :TagbarToggle<CR>
" Uncomment to open tagbar automatically whenever possible
"autocmd BufEnter * nested :call tagbar#autoopen(0)


" --------------------------------------------------
" ------------------ NERDTree ----------------------
" --------------------------------------------------
nmap <silent> <Leader>ss :NERDTreeToggle<CR>


" --------------------------------------------------
" ----------------- NERDComment --------------------
" --------------------------------------------------
" Toggle comment
nnoremap <Leader>e :call NERDComment(0, "toggle")<C-m>


" --------------------------------------------------
" -------------- vim-expand-region -----------------
" --------------------------------------------------
" Press v over and over again to expand selection
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)


" --------------------------------------------------
" ----------------- incsearch ----------------------
" --------------------------------------------------
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)


" --------------------------------------------------
" ----------------- YouCompleteMe ------------------
" --------------------------------------------------
let g:ycm_path_to_python_interpreter = '/usr/bin/python3'
let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'

let g:ycm_collect_identifiers_from_tags_files = 1

" --------------------------------------------------
" -------------- The-NERD-Commenter ----------------
" --------------------------------------------------
" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1
" C comment style:
" let g:NERDCustomDelimiters = { 'c': { 'left': '/**','right': '*/' } }
" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1
" Enable trimming of trailing whitespace when uncommenting
let g:NERDTrimTrailingWhitespace = 1


" --------------------------------------------------
" ---------------- vim-gitgutter -------------------
" --------------------------------------------------
let g:gitgutter_map_keys = 0  " Disable all mappings for gitgutter.


" --------------------------------------------------
" ----------------- vim-xkbswitch ------------------
" --------------------------------------------------
let g:XkbSwitchEnabled = 1
