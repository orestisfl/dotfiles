#!/usr/bin/env python3

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
        ["zenity", "--entry", f"--entry-text={focused.name}"],
        capture_output=True,
        text=True,
        check=True,
    )

    new_name = result.stdout.strip()
    assert new_name, "empty workspace name"

    if workspace.num > 0:
        target = f"{workspace.num}:{new_name}"
    else:
        target = new_name
    i3.command(f'rename workspace to "{target}"')


if __name__ == "__main__":
    main()
