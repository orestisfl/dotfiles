#!/usr/bin/python
import json
from subprocess import check_output

workspace_nums = [
    ws["num"] for ws in json.loads(check_output(["i3-msg", "-t", "get_workspaces"]))
]

for next_num in range(1, 50):
    if next_num not in workspace_nums:
        print(next_num)
        break
