let g:mapleader = "\<Space>"
let mapleader = "\<Space>"

" Open buffer
nnoremap <leader>b :Buffers<cr>
" Open file
nnoremap <leader>o :Files<cr>
" Tags
" nnoremap <leader>t :Tags<cr>
" History
nnoremap <leader>h :History<cr>

" To open a new empty buffer
" nmap <leader>t :enew<cr>

" Save file
nnoremap <Leader>w :w<CR>

" Treat long lines as break lines (useful when moving around in them)
map j gj
map k gk

" Remap VIM 0 to first non-blank character
map 0 ^

" Remap Y to yank the rest of the line.
map Y y$

" Split navigations. Replaced by tmux navigator.
nnoremap <C-J> <C-W><C-J>
nnoremap <C-Down> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-Up> <C-W><C-K>
nnoremap <C-Right> <C-W><C-L>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-Left> <C-W><C-H>
nnoremap <C-H> <C-W><C-H>

" Regex magix
nnoremap / /\v
cnoremap %s/ %s/\v
