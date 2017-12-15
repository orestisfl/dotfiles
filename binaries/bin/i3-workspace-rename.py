#!/usr/bin/env python3

import subprocess
import i3ipc

i3 = i3ipc.Connection()
workspaces = i3.get_workspaces()
for workspace in workspaces:
    if workspace["focused"]:
        num = workspace['num']
        print(f"Renaming workspace number {num}")
        assert(num > 0)
        new_name = subprocess.check_output('zenity --entry', shell=True).decode().strip()
        i3.command(f'rename workspace to "{num}:{new_name}"')
