# Executes commands at login post-zshrc.

export EDITOR=nvim
export VISUAL=nvim
export SYSTEMD_EDITOR=nvim

export GOPATH=$HOME/go
export PATH=$HOME/bin/exes:$PATH
export PATH=$PATH:/usr/bin/core_perl
# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
unset MANPATH  # delete if you already modified MANPATH elsewhere in your configuration

# git ls-files: all tracked files, even if starting with dot
# fd --type f: all non-ignored files, even if in submodule
# sed: fd prepends `./` when used in pipe to prevent vulnerability with filenames starting with dash, e.g. `-rf`
# awk: Only unique matches
export FZF_DEFAULT_COMMAND='{ fd --type f & git ls-files } | sed -E "s/^\.\///" | awk "!x[\$0]++"'
export FZF_COMPLETION_TRIGGER='~~'
export FZF_DEFAULT_OPTS='--bind alt-a:select-all,alt-d:deselect-all'
export FZF_CTRL_T_COMMAND='fd'
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
export FZF_ALT_C_COMMAND='fd --type d'
export FZF_ALT_C_OPTS="--preview 'tree -C {}'"

[[ -z $DISPLAY && $XDG_VTNR -eq 1 && -z "$TMUX" ]] && exec startx
export TERM=linux
