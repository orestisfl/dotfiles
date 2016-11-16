# To see the key combo you want to use just do:
# cat > /dev/null
# And press it

#bindkey "^R" history-incremental-search-backward : Replaced by fzf.
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^D" delete-char
bindkey "^F" forward-char
bindkey "^B" backward-char

# bind UP and DOWN arrow keys
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

# zsh-history-substring-search
# bind UP and DOWN arrow keys (compatibility fallback
# for Ubuntu 12.04, Fedora 21, and MacOSX 10.9 users)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# bind P and N for EMACS mode
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down

# bind k and j for VI mode
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# delete key
bindkey "^[[3~"  delete-char
bindkey "^[3;5~" delete-char
# ctrl+left/right
bindkey '^[Oc' forward-word
bindkey '^[Od' backward-word

# http://unix.stackexchange.com/a/319854/63367
# alt+backspace delete to next slash.
bindkey '^[^?' slash-backward-kill-word

# page up/down match starting string, not just substring
bindkey "^[[5~" history-beginning-search-backward
bindkey "^[[6~" history-beginning-search-forward

# http://stackoverflow.com/a/842370/3430986
# bind S-Tab for auto-complete
bindkey '^[[Z' reverse-menu-complete

# Edit command line in full screen editor.
# http://unix.stackexchange.com/a/34251/63367
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# deer file manager
bindkey '\ek' deer

# jump
bindkey "^J" jump
