#!/bin/sh
exec j4-dmenu-desktop --display-binary --no-generic --dmenu="(cat ; (stest -flx $(echo $PATH | tr : ' ') | sort -u)) | rofi -i -dmenu"
