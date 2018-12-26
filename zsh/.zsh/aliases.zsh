# Subtitute old software with modern and improve some commands.
alias vi='vim'
alias vim='nvim'
alias rename='perl-rename'
alias diff='colordiff'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ag='ag --pager=less'

# ls related
alias exa=' exa --git'
alias ls='ls --color=auto'
alias l='exa -lh --group-directories-first'
alias lr='exa -lh -R --group-directories-first'  # Lists human readable sizes, recursively.
alias lk='exa -lh -Sr --group-directories-first' # Lists sorted by size, largest last.
alias lt='ls -lh -tr'                            # Lists sorted by date, most recent last.
alias lc='lt -c'                                 # Lists sorted by date, most recent last, shows change time.

# c: Copy to clipboard, v:Paste from clipboard
alias c="xclip -in -selection clipboard"
alias v="xclip -o | sed -e '\$a\'"

# Shortcuts
alias ydl="youtube-dl -f best"
alias ydl-music="youtube-dl -f bestaudio -x"
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"
