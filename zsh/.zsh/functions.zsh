# Based on: https://unix.stackexchange.com/a/605328
function histdel () {
    line="$(fc -l 0 | awk '{$1=$1};1' | fzf --tac | cut -d ' ' -f 1)" || return

    HISTORY_IGNORE=${(b)history[$line]}

    builtin fc -W
    builtin fc -p $HISTFILE $HISTSIZE $SAVEHIST

    print "Deleted '$HISTORY_IGNORE' from history."
}

function waitpidof() {
    [[ -z "$1" ]] && echo "Usage: $0 <name of process>" && return 1
    while (pidof "$1" || (sleep 5 && pidof "$1")); do sleep 1; done
}

# launch an app
function launch {
    type $1 >/dev/null || { print "$1 not found" && return 1 }
    $@ &>/dev/null &|
}

function vix() {
    file=${1:-}
    if [[ -z "$file" ]]; then
        nvim
    else
        touch "$file"
        chmod +x "$file"
        nvim "$file"
    fi
}

# Pretty print specified PATH.
# If no argument is supplied use $PATH.
function print_path() {
    if [ ! $1 ] ;then
    1=$PATH
    fi
    echo $1 | tr ":" "\n" | \
    awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\"); \
           sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\"); \
           sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\"); \
           sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\"); \
           sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\"); \
           sub(\"/share\", \"$fg_no_bold[red]/share$reset_color\"); \
           print }"
}

function swap_2_files(){
    local TMPFILE="tmp.$(basename $1)$(basename $2)"
    mv $1 $TMPFILE && mv $2 $1 && mv $TMPFILE $2
}

function rec_fix_trailing_whitespace(){
    find . -name '.git' -prune -o -type f -name "$1" -exec sed --in-place 's/[[:space:]]\+$//' {} \+
}

# colored man
# https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/colored-man-pages/colored-man-pages.plugin.zsh
man() {
    env \
        LESS_TERMCAP_mb=$(printf "\e[1;31m") \
        LESS_TERMCAP_md=$(printf "\e[1;31m") \
        LESS_TERMCAP_me=$(printf "\e[0m") \
        LESS_TERMCAP_se=$(printf "\e[0m") \
        LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
        LESS_TERMCAP_ue=$(printf "\e[0m") \
        LESS_TERMCAP_us=$(printf "\e[1;32m") \
        PAGER="${commands[less]:-$PAGER}" \
        _NROFF_U=1 \
        PATH="$HOME/bin:$PATH" \
            man "$@"
}

function color_to_greyscale_pdf(){
    if [ ! $2 ] ;then
        2=$(basename $1 .pdf)
        2+="-greyscale.pdf"
    fi
    gs \
        -sOutputFile=$2 \
        -sDEVICE=pdfwrite \
        -sColorConversionStrategy=Gray \
        -dProcessColorModel=/DeviceGray \
        -dCompatibilityLevel=1.4 \
        -dNOPAUSE \
        -dBATCH \
        $1
}

function pdfa4(){
    if [ ! $1 ] ;then
        return 1
    fi
    if [ ! $2 ] ;then
        2=$(basename $1 .pdf)
        2+="-a4.pdf"
    fi
    gs -sDEVICE=pdfwrite -sPAPERSIZE=a4 -dAutoRotatePages=/All -dFIXEDMEDIA -dPDFFitPage -dCompatibilityLevel=1.4 -o $2 $1
}

function venv() {
    [[ ! $1 ]] && echo 'This function needs an argument' && return 1
    [[ $2 ]] && echo 'This function takes exactly one argument' && return 1

    local dir="$HOME/.cache/myenvs/$1"
    [[ -d "$dir" ]] && source "$dir/bin/activate" && return 0

    python3 -m venv "$dir"
    source "$dir/bin/activate"
    pip install -U pip
    pip install black ipdb ipython loguru pylint tqdm
}

slash-backward-kill-word() {
    local WORDCHARS="*?_-.[]~=&;!#$%^(){}<>"
    zle backward-kill-word
}
zle -N slash-backward-kill-word

# C-e: open file with mimeopen
# C-c: cd to dirname of file
# Enter: open with xdg-open
fo(){
    local out ret key file

    local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
        -o -type f -print \
        -o -type d -print \
        -o -type l -print 2> /dev/null | cut -b3-"}"
    out=$(eval "$cmd" | fzf --exit-0 --expect=ctrl-e,ctrl-c,ctrl-o)
    ret=$?
    key=$(head -1 <<< "$out")
    file=$(head -2 <<< "$out" | tail -1)
    if [ -n "$file" ]; then
        # zle redisplay
        # typeset -f zle-line-init >/dev/null && zle zle-line-init
        if [ "$key" = ctrl-e ]; then
            BUFFER="mimeopen -a $file"
            zle accept-line
        elif [ "$key" = ctrl-c ]; then
            cd "$(dirname "$file")"
        elif [ "$key" = ctrl-o ]; then
            true
        else
            launch xdg-open "$file"
        fi
        zle reset-prompt
    fi
    return $ret
}
zle -N fo

zoxide_cd () {
    local dir
    dir=$(zoxide query -i)
    cd -- $dir
    zle reset-prompt
}

zle -N zoxide_cd
