# Subtitute old software with modern and improve some commands.
alias cat=bat
alias diff=colordiff
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias rename=perl-rename
alias vi=vim
alias vim=nvim
alias rg="rg --hidden --glob '!.git'"

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
alias drm='docker run -it --rm'
alias drmv='docker run -it --rm -v "$PWD:/workdir" --workdir /workdir'
alias ghis='gh issue list -L 100 | fzf --preview "gh issue view {+1}"'
alias ghpr="gh pr list | fzf --preview 'gh pr diff --color=always {+1}' | awk '{print \$1}' | xargs --no-run-if-empty gh pr checkout"
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"
alias sdi='systemd-inhibit --what=handle-lid-switch'
alias ydl-music-mp3='yt-dlp -f bestaudio -x --audio-format mp3'
alias ydl-music='yt-dlp -f bestaudio -x'
alias ydl-playlist="yt-dlp -f best --write-srt -o '%(autonumber)s-%(title)s.%(ext)s'"
alias ydl=yt-dlp

# Typos
alias υαυ=yay
