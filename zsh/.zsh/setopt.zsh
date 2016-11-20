# ===== Basics
setopt no_beep  # don't beep on error
setopt interactive_comments  # Allow comments even in interactive shells (especially for Muness)

# ===== Changing Directories
setopt auto_cd  # If you type foo, and it isn't a command, and it is a directory in your cdpath, go there
setopt cdablevarS  # if argument to cd is the name of a parameter whose value is a valid directory, it will become the current directory
setopt pushd_ignore_dups  # don't push multiple copies of the same directory onto the directory stack

# ===== Expansion and Globbing
setopt extended_glob  # treat  #, ~, and ^ as part of patterns for filename generation

# ===== History
# also from https://github.com/sorin-ionescu/prezto/blob/master/modules/history/init.zsh
setopt append_history  # Allow multiple terminal sessions to all append to one zsh command history
setopt BANG_HIST  # Treat the '!' character specially during expansion.
setopt extended_history  # save timestamp of command and duration
setopt inc_append_history  # Add comamnds as they are typed, don't wait until shell exit
setopt hist_expire_dups_first  # when trimming history, lose oldest duplicates first
setopt hist_ignore_dups  # Do not write events to history that are duplicates of previous events
setopt hist_ignore_space  # remove command line from history list when first character on the line is a space
setopt hist_find_no_dups  # When searching history don't display results already cycled through twice
setopt HIST_IGNORE_ALL_DUPS  # Delete an old recorded event if a new event is a duplicate.
setopt hist_reduce_blanks  # Remove extra blanks from each command line being added to history
setopt HIST_SAVE_NO_DUPS  # When writing out the history file, older commands that duplicate newer ones are omitted.
setopt hist_verify  # don't execute, just expand history
setopt share_history  # Share history between all sessions.

# ===== Completion
setopt always_to_end  # When completing from the middle of a word, move the cursor to the end of the word
setopt auto_menu  # show completion menu on successive tab press. needs unsetop menu_complete to work
setopt auto_name_dirs  # any parameter that is set to the absolute name of a directory immediately becomes a name for that directory
setopt complete_in_word  # Allow completion from within a word/phrase
setopt PATH_DIRS  # Perform path search even on command names with slashes.
setopt AUTO_LIST  # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH  # If completed parameter is a directory, add a trailing slash.

unsetopt menu_complete  # do not autoselect the first completion entry

# ===== Correction
# http://superuser.com/a/610025/253307
unset correctall  # no spelling correction for arguments
setopt correct  # spelling correction for commands

# ===== Prompt
setopt prompt_subst  # Enable parameter expansion, command substitution, and arithmetic expansion in the prompt
setopt transient_rprompt  # only show the rprompt on the current prompt

# ===== Scripts and Functions
setopt multios  # perform implicit tees or cats when multiple redirections are attempted

# ===== Others
# These chars don't terminate a word.
export WORDCHARS='&#$%'

# Commands that last longer than $REPORTTIME will make zsh print usage statistics afterwards.
REPORTTIME=5
