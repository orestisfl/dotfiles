#!/usr/bin/env python
import json
import time
from subprocess import check_output

import i3ipc


def cb(_=None, e=None):
    d = json.loads(check_output(["i3-msg", "-t", "get_workspaces"]).decode())

    if not any(ws.get("name") == "foo" for ws in d):
        # foo = {"name": "foo", "output": "whatever"}
        foo = {"name": "foo"}
        d.append(foo)

    print(json.dumps(d))


i3 = i3ipc.Connection()
i3.on(i3ipc.Event.WORKSPACE, cb)
i3.on(i3ipc.Event.OUTPUT, cb)
cb()
i3.main()
