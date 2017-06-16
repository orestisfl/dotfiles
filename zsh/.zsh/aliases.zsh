# pacman aliases
alias pacinfo='pacman -Si'       # Display information about a given package in the repositories
alias pacman_clean_cache="sudo pacman -Scc"       # Clean cache - delete all the package files in the cache
alias pacman_list_files_by_pack="pacman -Ql"        # List all files installed by a given package
alias pacman_show_packs_by_file="pacman -Qo"       # Show package(s) owning the specified file(s)
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"

# Subtitute old software with modern and improve some commands.
alias vi='vim'
alias rename='perl-rename'
alias exa=' exa --git'
alias diff='colordiff'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# ls related
# all command start with space so they are not written in history
alias ls=' ls --color=auto'
alias l=' exa -lh'
alias lr=' exa -lh -R'         # Lists human readable sizes, recursively.
alias lk=' exa -lh -Sr'        # Lists sorted by size, largest last.
alias lt=' ls -lh -tr'        # Lists sorted by date, most recent last.
alias lc=' lt -c'         # Lists sorted by date, most recent last, shows change time.
alias k=' k'

# c: Copy to clipboard, v:Paste from clipboard
alias c="xclip -in -selection clipboard"
alias v="xclip -o"

# always run ipython inside current virtualenv
alias ipy="python -c 'import IPython; IPython.terminal.ipapp.launch_new_instance()'"

# git aliases
alias git-is="git show \$(git log --pretty=oneline| fzf | awk '{print \$1}')"

# Shortcuts
alias ydl="youtube-dl -f best"
alias aurupg='pacaur -Syu --ignore=$IGNOREPKGS'
alias pacupg='sudo pacman -Syu'
alias weather="curl wttr.in/Thessaloniki"
alias sysstart="sudo systemctl start"
alias sysstop="sudo systemctl stop"
alias sysenable="sudo systemctl enable"
alias sysdisable="sudo systemctl disable"
alias cgrep="grep --exclude=tags --exclude-dir=.git --exclude-dir=.idea --binary-files=without-match --recursive --line-number --initial-tab"
