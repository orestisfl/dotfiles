#!/usr/bin/env python3
# i3ipc sets Con/CommandReply attributes dynamically.
# pyright: reportAttributeAccessIssue=false

import subprocess

import i3ipc


def main() -> None:
    i3 = i3ipc.Connection()

    focused = i3.get_tree().find_focused()
    assert focused is not None, "no focused window"

    workspace = focused.workspace()
    assert workspace is not None, "focused window has no workspace"
    print(f"Renaming workspace {workspace.name!r} (num={workspace.num})")

    result = subprocess.run(
        ["yad", "--entry", f"--entry-text={focused.name}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:  # cancel / escape
        return

    # "4: name" (or "4") renumbers the workspace as well; empty keeps
    # just the number.
    new_name = result.stdout.strip()
    num = workspace.num
    prefix, _, rest = new_name.partition(":")
    if prefix.strip().isdecimal():
        num, new_name = int(prefix), rest.strip()

    if num > 0:
        target = f"{num}:{new_name}" if new_name else str(num)
    elif new_name:
        target = new_name
    else:
        raise SystemExit("empty name for unnumbered workspace")
    for reply in i3.command(f'rename workspace to "{target}"'):
        if not reply.success:
            raise SystemExit(f"rename to {target!r} failed: {reply.error}")


if __name__ == "__main__":
    main()
