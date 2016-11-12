#!/usr/bin/env python
# -*- coding: utf-8 -*-
import i3

def main(args):
    # Assume only one window is focused.
    focused_window = i3.filter(focused=True)[0]
    if focused_window['sticky']:
        i3.sticky('disable')
        i3.border('normal')
        i3.floating('disable')
    else:
        i3.floating('enable')
        i3.sticky('enable')
        i3.border('none')
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv))
