#!/usr/bin/env python
import i3ipc

HIDDEN = "_hidden"
i3 = i3ipc.Connection()


def main():
    if HIDDEN in [ws.name for ws in i3.get_workspaces()]:
        i3.command(f"[workspace={HIDDEN}] move to workspace current, focus")
    else:
        i3.command(f'[class=keepassxc title="KeePassXC$"] move to workspace {HIDDEN}')


if __name__ == "__main__":
    main()
