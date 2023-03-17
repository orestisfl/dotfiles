# Subtitute old software with modern and improve some commands.
alias vi='vim'
alias vim='nvim'
alias rename='perl-rename'
alias diff='colordiff'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ag='rg -S'
alias cat=bat

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
alias v="(xclip -o -selection clipboard || xclip -o) | sed -e '\$a\'"

# Shortcuts
alias ydl="yt-dlp"
alias ydl-music="yt-dlp -f bestaudio -x"
alias ydl-music-mp3="yt-dlp -f bestaudio -x --audio-format mp3"
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias ydl-playlist="yt-dlp -f best --write-srt -o '%(autonumber)s-%(title)s.%(ext)s'"
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"
alias drr='docker run -it --rm'
alias lastssh="tac ~/.zhistory | grep -oP -m1 'orestis@([^\s]+)'"
alias sdi='systemd-inhibit --what=handle-lid-switch'

# Typos
alias υαυ=yay
