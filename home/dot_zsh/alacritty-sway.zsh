# Link each alacritty shell to its sway container so alacritty.sh can find
# the focused window's cwd on Wayland (where ALACRITTY_WINDOW_ID is not
# externally addressable).
#
# Flow (once, after first prompt):
#   1. Set a unique token as the window title via OSC 2.
#   2. Poll `swaymsg -t get_tree` for a container with that name; grab con_id.
#   3. `swaymsg [con_id=N] mark --add _<ALACRITTY_WINDOW_ID>`.
#   4. Restore the title to the same format precmd uses.
#
# alacritty.sh reads the mark on the focused window and the matching file
# under $XDG_RUNTIME_DIR/alacritty-cwd/<id>. The sway IPC round-trips are
# deferred off the prompt's critical path via zsh-defer.

if [[ -n "$ALACRITTY_WINDOW_ID" && -n "$SWAYSOCK" && -t 1 ]] && (( $+commands[swaymsg] && $+commands[jq] )); then
    _alacritty_sway_cwd_dir="${XDG_RUNTIME_DIR:-/tmp}/alacritty-cwd"
    _alacritty_sway_cwd_file="$_alacritty_sway_cwd_dir/$ALACRITTY_WINDOW_ID"
    _alacritty_sway_mark="_$ALACRITTY_WINDOW_ID"
    [[ -d "$_alacritty_sway_cwd_dir" ]] || mkdir -p -- "$_alacritty_sway_cwd_dir"

    _alacritty_sway_write_cwd() { print -r -- "$PWD" >| "$_alacritty_sway_cwd_file" }

    _alacritty_sway_install_mark() {
        local token="_asway_${RANDOM}${RANDOM}_$$" id="" i
        # /dev/tty: reach alacritty even if zsh-defer redirected stdout.
        printf '\e]2;%s\a' "$token" >/dev/tty 2>/dev/null
        for i in {1..50}; do
            id=$(swaymsg -t get_tree 2>/dev/null \
                | jq -r --arg t "$token" 'first(.. | objects | select(.name? == $t) | .id) // empty')
            [[ -n "$id" ]] && break
            sleep 0.02
        done
        [[ -n "$id" ]] && swaymsg -q -- "[con_id=$id] mark --add $_alacritty_sway_mark" 2>/dev/null
        # Keep in sync with precmd in prompt.zsh.
        print -n '\e]0;zsh\a' >/dev/tty 2>/dev/null
    }

    # The sway mark dies with the container; only the cwd file needs cleanup.
    _alacritty_sway_cleanup() { rm -f -- "$_alacritty_sway_cwd_file" }

    (( $+functions[add-zsh-hook] )) || autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _alacritty_sway_write_cwd
    add-zsh-hook zshexit _alacritty_sway_cleanup
    _alacritty_sway_write_cwd

    zsh-defer _alacritty_sway_install_mark
fi
