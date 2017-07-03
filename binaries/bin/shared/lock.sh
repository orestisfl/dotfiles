#!/bin/bash
SCREEN=/tmp/screen.png
LOGO=$HOME/.local/share/lock.png
RES=${LOCK_RESOLUTION}
FILTER="boxblur=5:1,overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/4"
SCREENSHOT_CMD="ffmpeg -f x11grab -video_size $RES -y -i $DISPLAY -i $LOGO -filter_complex \"$FILTER\" -vframes 1 $SCREEN -loglevel quiet"
I3LOCK_CMD="i3lock -i $SCREEN -t -n"
