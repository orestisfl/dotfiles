#!/usr/bin/env python
# -*- coding: utf-8 -*-
import i3ipc


def main(args):
    i3 = i3ipc.Connection()
    focused = i3.get_tree().find_focused()
    if focused.sticky and focused.floating.endswith('on'):
        focused.command('border normal, floating disable')
    else:
        focused.command('floating enable, sticky enable, border none')
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv))
