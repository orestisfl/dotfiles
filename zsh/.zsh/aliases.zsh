# pacman aliases
alias pacinfo='pacman -Si'       # Display information about a given package in the repositories
alias pacman_clean_cache="sudo pacman -Scc"       # Clean cache - delete all the package files in the cache
alias pacman_list_files_by_pack="pacman -Ql"        # List all files installed by a given package
alias pacman_show_packs_by_file="pacman -Qo"       # Show package(s) owning the specified file(s)
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"

# all command start with space so they are not written in history
alias l=' k -h'
alias lr=' ls -lh -R'         # Lists human readable sizes, recursively.
alias lm=' k -h| "$PAGER"' # Lists human readable sizes, hidden files through pager.
alias lx=' ls -lh -XB'        # Lists sorted by extension (GNU only).
alias lk=' ls -lh -Sr'        # Lists sorted by size, largest last.
alias lt=' ls -lh -tr'        # Lists sorted by date, most recent last.
alias lc=' lt -c'         # Lists sorted by date, most recent last, shows change time.
alias lu=' lt -u'         # Lists sorted by date, most recent last, shows access time.
alias ls=' ls --color=auto'
alias k=' k'

# Subtitute old software with modern.
alias vi='vim'
alias rename='perl-rename'
alias grep='grep --color=auto'

# c: Copy to clipboard, v:Paste from clipboard
alias c="xclip -in -selection clipboard"
alias v="xclip -o"

# always run ipython inside current virtualenv
alias ipy="python -c 'import IPython; IPython.terminal.ipapp.launch_new_instance()'"

alias weather="curl wttr.in/Thessaloniki"

# git aliases
alias git-is="git show \$(git log --pretty=oneline| fzf | awk '{print \$1}')"

# Shortcuts
alias ydl="youtube-dl -f best"

# fasd
#alias a='fasd -a'        # any
alias s='fasd -si'       # show / search / select
alias d='fasd -d'        # directory
alias f='fasd -f'        # file
alias sd='fasd -sid'     # interactive directory selection
alias sf='fasd -sif'     # interactive file selection
# function to execute built-in cd
fasd_cd() {
  if [ $# -le 1 ]; then
    fasd "$@"
  else
    local _fasd_ret="$(fasd -e echo "$@")"
    [ -z "$_fasd_ret" ] && return
    [ -d "$_fasd_ret" ] && cd "$_fasd_ret" || echo "$_fasd_ret"
  fi
}
alias z='fasd_cd -d'     # cd, same functionality as j in autojump
alias zz='fasd_cd -d -i' # cd with interactive selection
