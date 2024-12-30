#!/usr/bin/env python3

import subprocess

import i3ipc

i3 = i3ipc.Connection()

focused = i3.get_tree().find_focused()
num = focused.workspace().num

if not num or num <= 0:
    import sys

    sys.exit(0)

print(f"Renaming workspace number {num}")
cmd = f"zenity --entry --entry-text='{focused.name}'"
new_name = subprocess.check_output(cmd, shell=True).decode().strip()
new_name = new_name.replace('"', r"\"")
i3.command(f'rename workspace to "{num}:{new_name}"')
