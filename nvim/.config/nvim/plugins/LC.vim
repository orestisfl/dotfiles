" For completion
Plug 'https://github.com/Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
let g:deoplete#enable_at_startup = 1

Plug 'https://github.com/autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }
" Debug:
" let g:LanguageClient_loggingLevel = 'INFO'
" let g:LanguageClient_loggingFile =  expand('~/.local/share/nvim/LanguageClient.log')
" let g:LanguageClient_serverStderr = expand('~/.local/share/nvim/LanguageServer.log')
" To debug pyls use:
    " \ 'python': ['pyls', '-vvv', '--log-file', '/tmp/out.log'],
" For pyls options see:
" https://github.com/palantir/python-language-server/blob/develop/vscode-client/package.json
let g:LanguageClient_serverCommands = {
    \ 'c': ['ccls'],
    \ 'cpp': ['ccls'],
    \ 'python': ['pyls'],
    \ 'tex': ['texlab'],
    \ 'rust': ['rls'],
    \ 'sh': ['bash-language-server', 'start'],
    \ 'javascript': ['javascript-typescript-stdio'],
    \ 'typescript': ['javascript-typescript-stdio']
    \ }
let g:LanguageClient_hoverPreview = 'Always'  " or 'Never'
let g:LanguageClient_settingsPath = $HOME . '/.config/nvim/settings.json'
" handles the function signatures displaying
Plug 'Shougo/echodoc.vim'
let g:echodoc#enable_at_startup = 1
let g:echodoc#type = 'signature'

" Snippet support
Plug 'https://github.com/Shougo/neosnippet.vim'
Plug 'https://github.com/Shougo/neosnippet-snippets'

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
  autocmd FileType c,cpp,python,tex,rust,sh,javascript,typescript call SetLSPShortcuts()
augroup END

nnoremap <F5> :call LanguageClient_contextMenu()<CR>

" Plugin key-mappings.
" Note: It must be "imap" and "smap".  It uses <Plug> mappings.
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
" Note: It must be "imap" and "smap".  It uses <Plug> mappings.
"imap <expr><TAB>
" \ pumvisible() ? "\<C-n>" :
" \ neosnippet#expandable_or_jumpable() ?
" \    "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
