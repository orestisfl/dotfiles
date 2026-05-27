#!/usr/bin/env python3
"""Dynamically rename i3/sway workspaces based on their windows.

For each workspace, the highest-priority matching window (per RULES below)
provides the workspace label. The leading workspace number is preserved so
`workspace number N` bindings keep working.

By default, applies the rename once and then subscribes to IPC events to
keep names in sync. Use --once to apply once and exit. Use --force to also
overwrite workspaces whose current name looks user-customized (anything
beyond a bare number or a label this process previously set).
"""

from __future__ import annotations

import argparse
import logging
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

import i3ipc

log = logging.getLogger("ws-auto-rename")


def app(con: i3ipc.Con) -> str:
    """app_id (sway native) or class/instance (X / XWayland), lowercased."""
    return (con.app_id or con.window_class or con.window_instance or "").lower()


def title(con: i3ipc.Con) -> str:
    return (con.name or "").strip()


# --- match helpers ----------------------------------------------------------


def app_in(*needles: str) -> Callable[[i3ipc.Con], bool]:
    def f(con: i3ipc.Con) -> bool:
        a = app(con)
        return any(n in a for n in needles)

    return f


def title_re(*pats: str) -> Callable[[i3ipc.Con], bool]:
    regs = [re.compile(p, re.IGNORECASE) for p in pats]

    def f(con: i3ipc.Con) -> bool:
        t = title(con)
        return any(r.search(t) for r in regs)

    return f


# --- title transformers -----------------------------------------------------

# Splits on en/em dash or hyphen surrounded by whitespace.
_DASH_SPLIT = re.compile(r"\s+[—–-]\s+")


def first_chunk(con: i3ipc.Con) -> str:
    parts = [p for p in _DASH_SPLIT.split(title(con)) if p]
    return parts[0] if parts else app(con)


def jetbrains_project(con: i3ipc.Con) -> str:
    # Title is "<project> – <file>" (en dash) on modern JetBrains IDEs.
    return first_chunk(con)


def jetbrains_with_icon(icon: str) -> Callable[[i3ipc.Con], str]:
    def f(con: i3ipc.Con) -> str:
        return f"{icon} {jetbrains_project(con)}"

    return f


def evince_pdf(con: i3ipc.Con) -> str:
    name = first_chunk(con)
    return re.sub(r"\.pdf$", "", name, flags=re.IGNORECASE)


# Cursor agent terminal titles look like "<task> - ⏳ Working ···" /
# "<task> - ✅ Ready" / "<task> - ❌ Error". Strip the status suffix.
_CURSOR_STATUS = re.compile(r"\s*-\s*[⏳✅❌▶️⏸️].*$")


def cursor_agent(con: i3ipc.Con) -> str:
    return _CURSOR_STATUS.sub("", title(con)).strip() or "cursor"


def claude_agent(con: i3ipc.Con) -> str:
    t = title(con)
    t = re.sub(r"^\s*claude\s*[:\-]\s*", "", t, flags=re.IGNORECASE)
    return t.strip() or "claude"


def constant(name: str) -> Callable[[i3ipc.Con], str]:
    return lambda _con: name


# --- ghostty cwd ------------------------------------------------------------
#
# Mirrors the lookup in `term.sh`: read the WM mark on the focused window
# and look up the matching cwd file written by `ghostty-wm.zsh`. Ghostty is
# single-process on Linux, so pid-walking can't distinguish windows -- marks
# are the only reliable signal.

_HOME = Path.home()
_RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
_GHOSTTY_MARK_RE = re.compile(r"^_(.+)$")


def _ghostty_cwd_from_marks(con: i3ipc.Con) -> str | None:
    for mark in con.marks or []:
        m = _GHOSTTY_MARK_RE.match(mark)
        if not m:
            continue
        cwd_file = _RUNTIME / "ghostty-cwd" / m.group(1)
        try:
            cwd = cwd_file.read_text().strip()
        except OSError:
            continue
        if cwd and os.path.isdir(cwd):
            return cwd
    return None


def _shorten_path(path: str, limit: int = 30) -> str:
    """Smart-shrink a slash-separated path to ``limit`` chars.

    Abbreviates interior segments to their first character (or first two for
    dotfiles) one at a time until the result fits. The first and last segments
    are preserved; if the basename itself is too long it gets a leading
    ellipsis truncation.
    """
    if len(path) <= limit:
        return path

    parts = path.split("/")

    def abbrev(seg: str) -> str:
        if seg.startswith(".") and len(seg) > 2:
            return seg[:2]
        return seg[:1] if seg else seg

    for i in range(1, len(parts) - 1):
        seg = parts[i]
        short = abbrev(seg)
        if short and short != seg:
            parts[i] = short
            candidate = "/".join(parts)
            if len(candidate) <= limit:
                return candidate

    candidate = "/".join(parts)
    if len(candidate) <= limit:
        return candidate

    # Basename alone is too long: keep the abbreviated prefix and ellipsise
    # the front of the last component.
    head = "/".join(parts[:-1])
    if head:
        head += "/"
    avail = limit - len(head) - 1  # 1 char for the ellipsis
    last = parts[-1]
    if avail < 3:
        return "…" + path[-(limit - 1) :]
    return head + "…" + last[-avail:]


def ghostty_label(con: i3ipc.Con) -> str | None:
    """Path of the focused ghostty's cwd (``~``-prefixed, ≤30 chars).

    Returns ``None`` when the cwd can't be determined or the shell is sitting
    directly in ``$HOME`` — leaving the workspace unlabelled in that case.
    """
    cwd = _ghostty_cwd_from_marks(con)
    if not cwd:
        return None
    p = Path(cwd)
    try:
        resolved = p.resolve()
    except OSError:
        resolved = p
    try:
        home = _HOME.resolve()
    except OSError:
        home = _HOME
    if resolved == home:
        return None
    try:
        rel = resolved.relative_to(home)
        formatted = "~" if str(rel) == "." else f"~/{rel}"
    except ValueError:
        formatted = str(resolved)
    return _shorten_path(formatted, 30)


# --- rules (highest priority first) -----------------------------------------


@dataclass(frozen=True)
class Rule:
    name: str
    matches: Callable[[i3ipc.Con], bool]
    label: Callable[[i3ipc.Con], str]


RULES: list[Rule] = [
    Rule("zoom", app_in("zoom"), constant("zoom")),
    Rule("slack", app_in("slack"), constant("slack")),
    Rule("goland", app_in("goland"), jetbrains_with_icon("🐹")),
    Rule("rustrover", app_in("rustrover"), jetbrains_with_icon("🦀")),
    Rule("firefox", app_in("firefox"), constant("🌐")),
    Rule("chromium", app_in("chromium"), constant("🌐")),
    Rule("btop", title_re(r"\bbtop\b"), constant("btop")),
    Rule("htop", title_re(r"\bhtop\b"), constant("htop")),
    Rule(
        "cursor",
        lambda c: app_in("cursor")(c) or _CURSOR_STATUS.search(title(c)) is not None,
        cursor_agent,
    ),
    Rule("claude", title_re(r"\bclaude\b"), claude_agent),
    Rule("evince", app_in("evince"), evince_pdf),
    # Lowest priority: a bare ghostty workspace gets named after its cwd
    # (unless the shell sits in $HOME, in which case we leave it unlabelled).
    Rule("ghostty", app_in("com.mitchellh.ghostty"), ghostty_label),
]


# --- core -------------------------------------------------------------------


def workspace_label(ws: i3ipc.Con) -> str | None:
    leaves = ws.leaves()
    if not leaves:
        return None
    for rule in RULES:
        matches = [c for c in leaves if rule.matches(c)]
        if not matches:
            continue
        # Tie-break ties on the focused window (e.g. two Evince windows).
        winner = next((c for c in matches if c.focused), matches[0])
        label = rule.label(winner)
        # `None` means the rule explicitly declines to label this window;
        # fall through to the next matching rule (or no label at all).
        if label is None:
            continue
        return label or rule.name
    return None


def target_name(ws: i3ipc.Con) -> str:
    label = workspace_label(ws)
    if ws.num is not None and ws.num > 0:
        return f"{ws.num}:{label}" if label else str(ws.num)
    return label or ws.name


# Workspace names this process has assigned. Used to distinguish our own
# decorations from user-customized names (so we don't clobber the latter).
_OURS: set[str] = set()

# Bare numeric default like sway/i3 ships ("1", "2", ...).
_DEFAULT_NAME = re.compile(r"^\d+$")


def is_ours(ws: i3ipc.Con) -> bool:
    return _DEFAULT_NAME.match(ws.name) is not None or ws.name in _OURS


def rename(i3: i3ipc.Connection, ws: i3ipc.Con, force: bool = False) -> None:
    target = target_name(ws)
    if ws.name == target:
        return
    if not force and not is_ours(ws):
        log.debug("skip custom-named workspace %r", ws.name)
        return
    log.info("rename %r -> %r", ws.name, target)
    old = ws.name.replace('"', r"\"")
    new = target.replace('"', r"\"")
    i3.command(f'rename workspace "{old}" to "{new}"')
    _OURS.discard(ws.name)
    _OURS.add(target)


def rename_all(
    i3: i3ipc.Connection,
    workspaces: Iterable[i3ipc.Con] | None = None,
    force: bool = False,
) -> None:
    if workspaces is None:
        workspaces = i3.get_tree().workspaces()
    for ws in workspaces:
        rename(i3, ws, force=force)


# --- main -------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--once", action="store_true", help="apply once and exit (no subscribe)"
    )
    p.add_argument(
        "--force",
        action="store_true",
        help="rename even workspaces with user-customized names",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )

    i3 = i3ipc.Connection()
    rename_all(i3, force=args.force)
    if args.once:
        return

    def on_event(conn: i3ipc.Connection, _e) -> None:
        rename_all(conn, force=args.force)

    for ev in (
        "window::new",
        "window::close",
        "window::move",
        "window::title",
        "workspace::focus",
    ):
        i3.on(ev, on_event)
    i3.main()


if __name__ == "__main__":
    main()
