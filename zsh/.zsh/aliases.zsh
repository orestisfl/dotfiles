# Subtitute old software with modern and improve some commands.
alias cat=bat
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias rename=perl-rename
alias rg="rg --hyperlink-format=default --hidden --glob '!.git'"
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

# help
unalias run-help
alias help='autoload -Uz run-help && run-help'

# Shortcuts
alias autoremove='sudo pacman -Rns $(pacman -Qdtq)'
alias drm='docker run -it --rm'
alias drmv='docker run -it --rm -v "$PWD:/workdir" --workdir /workdir'
alias entrr='entr -rnc'
alias fd='fd --hyperlink'
alias ghis='gh issue list -L 100 | fzf --preview "gh issue view {+1}"'
alias ghpr="gh pr list | fzf --preview 'gh pr diff --color=always {+1}' | awk '{print \$1}' | xargs --no-run-if-empty gh pr checkout"
alias k8s-show-ns="kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n"
alias k='~/bin/kubectl-wrapper.py'
alias mksrcinfo='makepkg --printsrcinfo > .SRCINFO'
alias pipupg="pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"
alias sdi='systemd-inhibit --what=handle-lid-switch'
alias ydl-music-mp3='yt-dlp -f bestaudio -x --audio-format mp3'
alias ydl-music='yt-dlp -f bestaudio -x'
alias ydl-playlist="yt-dlp --write-subs -o '%(autonumber)s-%(title)s.%(ext)s'"
alias ydl='yt-dlp --write-subs'

# Typos
alias υαυ=yay
