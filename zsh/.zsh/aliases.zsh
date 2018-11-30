# Subtitute old software with modern and improve some commands.
alias vi='vim'
alias vim='nvim'
alias rename='perl-rename'
alias exa=' exa --git'
alias diff='colordiff'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ag='ag --pager=less'

# ls related
# all command start with space so they are not written in history
alias ls='ls --color=auto'
alias l='exa -lh --group-directories-first'
alias lr='exa -lh -R --group-directories-first'  # Lists human readable sizes, recursively.
alias lk='exa -lh -Sr --group-directories-first' # Lists sorted by size, largest last.
alias lt='ls -lh -tr'                            # Lists sorted by date, most recent last.
alias lc='lt -c'                                 # Lists sorted by date, most recent last, shows change time.

# c: Copy to clipboard, v:Paste from clipboard
alias c="xclip -in -selection clipboard"
alias v="xclip -o | sed -e '\$a\'"

# always run ipython inside current virtualenv
alias ipy="python -c 'import IPython; IPython.terminal.ipapp.launch_new_instance()'"

# Shortcuts
alias ydl="youtube-dl -f best"
alias ydl-music="youtube-dl -f bestaudio -x"
alias weather="curl wttr.in/Thessaloniki"
alias cgrep="grep --exclude=tags --exclude-dir=.git --exclude-dir=.idea --binary-files=without-match --recursive --line-number --initial-tab"
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"

