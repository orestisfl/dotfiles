# Sane opts from https://github.com/willghatch/zsh-saneopt/
# Load in the start so that they can get overriden later.
bindkey -e # default keymap, first command so that it doesn't override anything.
source ~/.zsh/zsh-saneopt/saneopt.plugin.zsh

# http://zanshin.net/2013/02/02/zsh-configuration-from-the-ground-up/
source ~/.zsh/colors.zsh
source ~/.zsh/setopt.zsh
source ~/.zsh/history.zsh
source ~/.zsh/prompt.zsh
source ~/.zsh/aliases.zsh
source ~/.zsh/functions.zsh

# https://github.com/wting/autojump
source /usr/share/autojump/autojump.zsh
# https://github.com/urbainvaes/fzf-marks
source /usr/share/fzf-marks/fzf-marks.zsh

# https://github.com/t413/zsh-background-notify.git
source /usr/share/zsh/plugins/zsh-background-notify/bgnotify.plugin.zsh

# command not found from pkgfile
source /usr/share/doc/pkgfile/command-not-found.zsh

# https://github.com/djui/alias-tips
export ZSH_PLUGINS_ALIAS_TIPS_TEXT="You know you have an alias for that, right? "
export ZSH_PLUGINS_ALIAS_TIPS_EXCLUDES="vi vim"
source ~/.zsh/alias-tips/alias-tips.plugin.zsh

# https://github.com/sorin-ionescu/prezto/blob/master/modules/completion/init.zsh
source ~/.zsh/zsh-completions.zsh

# https://github.com/tarruda/zsh-autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

export FZF_COMPLETION_TRIGGER='~~'
source /usr/share/fzf/completion.zsh
source /usr/share/fzf/key-bindings.zsh

# https://github.com/zsh-users/zsh-syntax-highlighting
# sudo pacman -S zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# https://github.com/zsh-users/zsh-history-substring-search
# pacaur -S zsh-history-substring-search-git
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Custom bindkeys have higher priority.
source ~/.zsh/bindkeys.zsh

# automatically remove duplicates from these arrays
typeset -U path cdpath fpath manpath
