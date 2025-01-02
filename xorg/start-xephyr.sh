#!/bin/bash -x
D="${D:-50}"
i3_path="$HOME/i3"
i3_build="$i3_path/build"
unset I3SOCK
export PATH="$i3_path:$i3_build:$PATH"
export TERMINAL=uxterm

finish() {
	i3-msg exit
	kill "$xephyr_pid"
	exit 0
}

handle_SIGINT() {
	finish &>/dev/null
}

set -m

Xephyr -name "$(Xephyr_$D)" -terminate -br -ac -noreset -screen 2000x900 :$D &
xephyr_pid=$!
export DISPLAY=:$D
echo "Ran Xephyr with :display $DISPLAY"
inotifywait --timeout 1 /tmp/.X11-unix/ || {
	echo 'Xephyr failed' >&2
	exit 1
}

userresources=$HOME/.Xresources
sysresources=/etc/X11/xinit/.Xresources

# merge in defaults and keymaps
if [ -f $sysresources ]; then
	xrdb -merge $sysresources
fi

if [ -f "$userresources" ]; then
	xrdb -merge "$userresources"
fi

trap handle_SIGINT INT
echo "Passing args '$*' to i3"
if [[ -n "$ISSUE_I3" ]]; then
	(i3 --moreversion 2>&- || i3 --version) >/tmp/version
	i3 -c /etc/i3/config --shmlog-size=26214400 "$@"
	i3-dump-log | vipe | bzip2 -c | curl --data-binary @- http://logs.i3wm.org
elif [[ -n "$GDB_I3" ]]; then
	gdb --args i3 -V -d all "$@"
else
	i3 -V "$@" 2>&1 &
	wait $!
fi
finish
