"""Shared infrastructure for the declarative reconciler: path constants, the
ReconcilePlan protocol, CombinedPlan, manifest helpers, and the
run_plan/run_apply/run_gui engine. Domain modules import from here; this
module never imports them, so the dependency graph stays acyclic.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Protocol

SYNC_DIR = Path(__file__).resolve().parent
ENTRY_POINT = SYNC_DIR / "sync.py"


class ReconcilePlan(Protocol):
    """Shared shape of the domain plans + CombinedPlan (read-only data)."""

    def has_actions(self) -> bool: ...
    def is_empty(self) -> bool: ...
    @property
    def action_count(self) -> int: ...
    def clean_extras(self) -> list[str]: ...
    def warnings(self) -> list[str]: ...
    def shell_command(self) -> str: ...
    def human_summary(self) -> str: ...


# ---- manifest rendering & parsing --------------------------------------


def render_manifest(path: Path) -> str:
    """Render a manifest via `chezmoi execute-template --init`."""
    if not shutil.which("chezmoi"):
        raise SystemExit("sync: chezmoi not on PATH; cannot render manifest")
    proc = subprocess.run(
        ["chezmoi", "execute-template", "--init"],
        input=path.read_text(),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"sync: failed to render manifest:\n{proc.stderr.strip()}")
    return proc.stdout


def strip_manifest_line(raw: str) -> str:
    """Drop `# comments` and whitespace; '' for blank/comment-only lines."""
    return raw.split("#", 1)[0].strip()


def load_manifest(
    path: Path,
    parse_fn: Callable[[str, str], tuple[list, list[str]]],
) -> tuple[list, list[str]]:
    """Render `path`, parse with `parse_fn`; render failure → one error string."""
    try:
        rendered = render_manifest(path)
    except SystemExit as exc:
        return [], [str(exc)]
    return parse_fn(rendered, str(path))


def manifest_check(load_fn: Callable[[], tuple[list, list[str]]]) -> int:
    """Validate a manifest: print parse errors to stderr, return 1 if any."""
    _, errs = load_fn()
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


# ---- combined orchestrator plan ----------------------------------------


@dataclass
class CombinedPlan:
    """Aggregate of (label, plan) pairs; same surface as a domain plan.
    `shell_command` chains each non-empty subplan with `&&` so a failure
    halts the rest.
    """

    parts: list[tuple[str, ReconcilePlan]]

    def has_actions(self) -> bool:
        return any(p.has_actions() for _, p in self.parts)

    def is_empty(self) -> bool:
        return all(p.is_empty() for _, p in self.parts)

    @property
    def action_count(self) -> int:
        return sum(p.action_count for _, p in self.parts)

    def clean_extras(self) -> list[str]:
        out: list[str] = []
        for label, p in self.parts:
            for x in p.clean_extras():
                out.append(f"{label}: {x}")
        return out

    def warnings(self) -> list[str]:
        return [f"[{label}] {w}" for label, p in self.parts for w in p.warnings()]

    def shell_command(self) -> str:
        sections = []
        for label, p in self.parts:
            if not p.has_actions():
                continue
            sections.append(f"# --- {label} ---\n{p.shell_command()}")
        return " \\\n  && ".join(sections)

    def human_summary(self) -> str:
        out: list[str] = []
        for label, p in self.parts:
            if p.is_empty():
                continue
            out.append(f"[{label}]")
            out.append(p.human_summary())
        return "\n".join(out)


# ---- execution engine --------------------------------------------------


def label_prefix(domain: str) -> str:
    """`sync` for the top-level combined orchestrator, `sync <domain>` otherwise."""
    return "sync" if domain == "all" else f"sync {domain}"


def run_plan(domain: str, plan: ReconcilePlan) -> int:
    prefix = label_prefix(domain)
    host = os.uname().nodename
    if plan.is_empty():
        print(f"{prefix}: nothing to do for {host}")
        return 0
    print(f"{prefix} · {host}")
    print(plan.human_summary())
    if plan.has_actions():
        print()
        print(plan.shell_command())
    return 0


def run_apply(domain: str, plan: ReconcilePlan) -> int:
    prefix = label_prefix(domain)
    for w in plan.warnings():
        print(f"{prefix}: WARNING {w}", file=sys.stderr)
    if not plan.has_actions():
        return 0
    cmd = plan.shell_command()
    print(cmd, file=sys.stderr)
    return subprocess.call(["bash", "-o", "pipefail", "-c", cmd])


def _notify(body: str, *, urgency: str = "normal") -> None:
    if shutil.which("notify-send"):
        subprocess.call(["notify-send", "-a", "sync", "-u", urgency, "sync", body])
    else:
        print(f"sync: {body}", file=sys.stderr)


def _has_display() -> bool:
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


def _dispatch_detached(domain: str) -> int:
    """Re-run ourselves as a transient --user systemd unit so the GUI survives
    the parent (chezmoi apply) exiting. The child re-enters `run_gui` with
    SYNC_DETACHED=1. Only reached when systemd-run is present.
    """
    child_args = ["gui"] if domain == "all" else [domain, "gui"]
    rc = subprocess.call(
        [
            "systemd-run",
            "--user",
            "--collect",
            f"--description=sync: declarative {domain} reconcile",
            "--setenv=SYNC_DETACHED=1",
            "python3",
            str(ENTRY_POINT),
            *child_args,
        ],
        stdin=subprocess.DEVNULL,
    )
    if rc != 0:
        print(f"sync: dispatch {domain} failed", file=sys.stderr)
    return rc


def run_gui(domain: str, plan: ReconcilePlan) -> int:
    """Shared yad → xdg-terminal-exec flow for any ReconcilePlan."""
    host = os.uname().nodename
    label = label_prefix(domain)
    warnings = plan.warnings()

    for w in warnings:
        print(f"{label}: WARNING {w}", file=sys.stderr)

    if not plan.has_actions():
        extras = plan.clean_extras()
        suffix = (", " + ", ".join(extras)) if extras else ""
        print(f"{label}: clean ({host}{suffix})", flush=True)
        return 0

    n = plan.action_count
    detached = os.environ.get("SYNC_DETACHED") == "1"

    if not detached:
        if not _has_display():
            print(
                f"{label}: {n} change(s) pending on {host} but no "
                f"desktop session; run `{label} plan` to inspect, "
                f"`{label} apply` to execute",
                file=sys.stderr,
            )
            return 0
        if shutil.which("systemd-run"):
            print(
                f"{label}: dispatching {n} change(s) on {host} to GUI…",
                flush=True,
            )
            return _dispatch_detached(domain)
        # No systemd-run: run the GUI in the foreground.
        print(
            f"{label}: systemd-run not found; running GUI in foreground",
            file=sys.stderr,
        )

    # Detached (or no systemd-run): pop yad → exec into xdg-terminal-exec.
    for tool in ("yad", "xdg-terminal-exec"):
        if not shutil.which(tool):
            _notify(
                f"{tool} missing — install it (paru -S {tool}) to use the GUI flow",
                urgency="critical",
            )
            print(plan.shell_command(), file=sys.stderr)
            return 1

    header = ["#!/usr/bin/env bash"]
    for w in warnings:
        header.append(f"# WARNING: {w}")
    if warnings:
        header.append("#")
    header.append("# Edit at will. Lines joined with && abort on first failure.")
    initial = "\n".join(header) + "\n" + plan.shell_command() + "\n"
    fd, edit_path = tempfile.mkstemp(suffix=".sh", prefix=f"sync.{domain}.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(initial)

        result = subprocess.run(
            [
                "yad",
                "--text-info",
                "--editable",
                "--title",
                f"{label} · {host}",
                "--width=900",
                "--height=500",
                "--button=Abort:1",
                "--button=Run:0",
                "--filename",
                edit_path,
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            _notify("Aborted by user.", urgency="low")
            return 0

        edited_body = result.stdout if result.stdout.strip() else initial
        pretty = "Sync" if domain == "all" else domain.capitalize()

        with open(edit_path, "w") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write("set -o pipefail\n")
            f.write("(\n")
            f.write(edited_body)
            if not edited_body.endswith("\n"):
                f.write("\n")
            f.write(")\n")
            f.write("rc=$?\n")
            f.write("if [[ $rc -eq 0 ]]; then\n")
            f.write(
                f'  notify-send -a sync -u low sync "{pretty} sync complete on $(hostname)"\n'
            )
            f.write("else\n")
            f.write(
                f'  notify-send -a sync -u critical sync "{pretty} sync failed (exit $rc) on $(hostname)"\n'
            )
            f.write("fi\n")
            f.write('echo\nread -n1 -r -s -p "Press any key to close…"\n')
            f.write('exit "$rc"\n')
        os.chmod(edit_path, 0o755)
    except OSError:
        if os.path.exists(edit_path):
            os.unlink(edit_path)
        raise

    os.execvp("xdg-terminal-exec", ["xdg-terminal-exec", edit_path])
