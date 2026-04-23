#!/usr/bin/env python3
# Works under i3 or sway: i3ipc picks the compositor via IPC socket env vars.
import i3ipc

workspaces = i3ipc.Connection().get_workspaces()
workspace_nums = [ws.num for ws in workspaces]
f = next(ws.num for ws in workspaces if ws.focused)

for next_num in range(f + 1, 50):
    if next_num not in workspace_nums:
        print(next_num)
        break
