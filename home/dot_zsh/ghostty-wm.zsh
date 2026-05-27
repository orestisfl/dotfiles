# Link each ghostty shell to its sway/i3 container so term.sh can find
# the focused window's cwd. Ghostty is single-process on Linux, so pid-based
# lookup can't tell windows apart -- we use WM marks instead.
#
# Flow (once, after first prompt):
#   1. Generate a random per-shell id (ghostty exposes no per-window env var).
#   2. Set a unique token as the window title via OSC 2.
#   3. Poll the WM tree for a container with that name; grab con_id.
#   4. `(sway|i3)msg [con_id=N] mark --add _<id>`.
#   5. Restore the title to the same format precmd uses.
#
# term.sh reads the mark on the focused window and the matching file
# under $XDG_RUNTIME_DIR/ghostty-cwd/<id>. The IPC round-trips are deferred
# off the prompt's critical path via zsh-defer.

if [[ "$TERM_PROGRAM" == "ghostty" && -t 1 ]] && (( $+commands[jq] )); then
    if [[ -n "$SWAYSOCK" ]] && (( $+commands[swaymsg] )); then
        _ghostty_wm_msg=swaymsg
    elif [[ "$XDG_SESSION_TYPE" == "x11" ]] && (( $+commands[i3-msg] )); then
        _ghostty_wm_msg=i3-msg
    fi
fi

if [[ -n "${_ghostty_wm_msg:-}" ]]; then
    _ghostty_wm_id="${RANDOM}${RANDOM}${$}"
    _ghostty_wm_cwd_dir="${XDG_RUNTIME_DIR:-/tmp}/ghostty-cwd"
    _ghostty_wm_cwd_file="$_ghostty_wm_cwd_dir/$_ghostty_wm_id"
    _ghostty_wm_mark="_$_ghostty_wm_id"
    [[ -d "$_ghostty_wm_cwd_dir" ]] || mkdir -p -- "$_ghostty_wm_cwd_dir"

    _ghostty_wm_write_cwd() { print -r -- "$PWD" >| "$_ghostty_wm_cwd_file" }

    _ghostty_wm_install_mark() {
        local token="_gwm_${RANDOM}${RANDOM}_$$" id="" i
        # /dev/tty: reach the terminal even if zsh-defer redirected stdout.
        printf '\e]2;%s\a' "$token" >/dev/tty 2>/dev/null
        for i in {1..50}; do
            id=$($_ghostty_wm_msg -t get_tree 2>/dev/null \
                | jq -r --arg t "$token" 'first(.. | objects | select(.name? == $t) | .id) // empty')
            [[ -n "$id" ]] && break
            sleep 0.02
        done
        [[ -n "$id" ]] && $_ghostty_wm_msg -q -- "[con_id=$id] mark --add $_ghostty_wm_mark" 2>/dev/null
        # Keep in sync with precmd in prompt.zsh.
        print -n '\e]0;zsh\a' >/dev/tty 2>/dev/null
    }

    # The WM mark dies with the container; only the cwd file needs cleanup.
    _ghostty_wm_cleanup() { rm -f -- "$_ghostty_wm_cwd_file" }

    (( $+functions[add-zsh-hook] )) || autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _ghostty_wm_write_cwd
    add-zsh-hook zshexit _ghostty_wm_cleanup
    _ghostty_wm_write_cwd

    zsh-defer _ghostty_wm_install_mark
fi
