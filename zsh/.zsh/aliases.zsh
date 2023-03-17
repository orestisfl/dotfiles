# Subtitute old software with modern and improve some commands.
alias cat=bat
alias diff=colordiff
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias rename=perl-rename
alias vi=vim
alias vim=nvim

# ls related
alias exa=' exa --git'
alias ls=exa
alias l='exa --long --header --group-directories-first'
alias la='l -a'
alias lk='l --sort=size'   # Lists sorted by size, largest last.
alias lr='l --recurse'     # Lists human readable sizes, recursively.
alias lt='l --sort=newest' # Lists sorted by date, most recent last.

# c: Copy to clipboard, v:Paste from clipboard
alias c="xclip -in -selection clipboard"
alias v="(xclip -o -selection clipboard || xclip -o) | sed -e '\$a\'"

# Shortcuts
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias drm='docker run -it --rm'
alias drmv='docker run -it --rm -v "$PWD:/workdir" --workdir /workdir'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"
alias sdi='systemd-inhibit --what=handle-lid-switch'
alias ydl=yt-dlp
alias ydl-music-mp3="yt-dlp -f bestaudio -x --audio-format mp3"
alias ydl-music="yt-dlp -f bestaudio -x"
alias ydl-playlist="yt-dlp -f best --write-srt -o '%(autonumber)s-%(title)s.%(ext)s'"

# Typos
alias υαυ=yay
