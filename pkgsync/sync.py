#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

MANIFEST = Path(__file__).resolve().parent / "packages.txt.tmpl"

# pkg | pkg:deps | pkg:explicit | -pkg. Name must not start with '-' so the
# optional leading dash is captured as the "forbidden" marker, not part of
# the name.
ENTRY_RE = re.compile(
    r"^(?P<minus>-)?(?P<name>[a-zA-Z0-9@._+][a-zA-Z0-9@._+-]*)"
    r"(?::(?P<reason>deps|explicit))?$"
)


@dataclass(frozen=True)
class Entry:
    name: str
    forbidden: bool
    # None  → must be installed; install reason is left alone if already there
    # "deps"     → must be installed and marked --asdeps
    # "explicit" → must be installed and marked --asexplicit
    reason: str | None


@dataclass
class Plan:
    to_remove: list[str] = field(default_factory=list)
    # Install with no --as flag (paru's default reason — explicit on first
    # install, untouched if already present).
    to_install_default: list[str] = field(default_factory=list)
    to_install_asdeps: list[str] = field(default_factory=list)
    to_install_asexplicit: list[str] = field(default_factory=list)
    # Reason flips for already-installed packages where the manifest's
    # opinion (`:deps` or `:explicit`) disagrees with pacman's record.
    to_flip_asdeps: list[str] = field(default_factory=list)
    to_flip_asexplicit: list[str] = field(default_factory=list)
    # Forbidden + installed packages we declined to remove because something
    # else still depends on them. Each entry: (pkg, sorted blockers).
    skipped_remove: list[tuple[str, list[str]]] = field(default_factory=list)

    def has_actions(self) -> bool:
        return bool(
            self.to_remove
            or self.to_install_default
            or self.to_install_asdeps
            or self.to_install_asexplicit
            or self.to_flip_asdeps
            or self.to_flip_asexplicit
        )

    def is_empty(self) -> bool:
        return not (self.has_actions() or self.skipped_remove)

    def warnings(self) -> list[str]:
        return [
            f"keeping {n} (still required by: {', '.join(blockers)})"
            for n, blockers in self.skipped_remove
        ]

    def shell_command(self) -> str:
        # ENTRY_RE already constrains names to a shell-safe charset, but
        # quote defensively in case the regex is ever relaxed.
        def join(names: list[str]) -> str:
            return " ".join(shlex.quote(n) for n in names)

        parts: list[str] = []
        if self.to_remove:
            parts.append(f"paru -Rns --noconfirm {join(self.to_remove)}")
        if self.to_install_default:
            parts.append(
                f"paru -S --needed --noconfirm {join(self.to_install_default)}"
            )
        if self.to_install_asdeps:
            parts.append(
                f"paru -S --needed --asdeps --noconfirm {join(self.to_install_asdeps)}"
            )
        if self.to_install_asexplicit:
            parts.append(
                f"paru -S --needed --asexplicit --noconfirm {join(self.to_install_asexplicit)}"
            )
        if self.to_flip_asdeps:
            parts.append(f"paru -D --asdeps {join(self.to_flip_asdeps)}")
        if self.to_flip_asexplicit:
            parts.append(f"paru -D --asexplicit {join(self.to_flip_asexplicit)}")
        return " \\\n  && ".join(parts)

    def human_summary(self) -> str:
        lines: list[str] = []
        for n in self.to_remove:
            lines.append(f"  - {n}")
        for n in self.to_install_default:
            lines.append(f"  + {n}")
        for n in self.to_install_asdeps:
            lines.append(f"  + {n}  (asdeps)")
        for n in self.to_install_asexplicit:
            lines.append(f"  + {n}  (asexplicit)")
        for n in self.to_flip_asdeps:
            lines.append(f"  ~ {n}  (mark asdeps)")
        for n in self.to_flip_asexplicit:
            lines.append(f"  ~ {n}  (mark explicit)")
        for n, blockers in self.skipped_remove:
            lines.append(f"  ! {n}  (kept; required by {', '.join(blockers)})")
        return "\n".join(lines)


# ---- rendering & parsing -----------------------------------------------


def render_manifest(path: Path = MANIFEST) -> str:
    """Render the manifest via `chezmoi execute-template --init`."""
    if not shutil.which("chezmoi"):
        raise SystemExit("pkgsync: chezmoi not on PATH; cannot render manifest")
    proc = subprocess.run(
        ["chezmoi", "execute-template", "--init"],
        input=path.read_text(),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"pkgsync: failed to render manifest:\n{proc.stderr.strip()}")
    return proc.stdout


def parse_rendered(
    text: str, source: str = "<rendered>"
) -> tuple[list[Entry], list[str]]:
    """Parse fully-rendered manifest text. Returns (entries, errors)."""
    entries: list[Entry] = []
    errors: list[str] = []
    seen: dict[str, str] = {}

    for lineno, raw in enumerate(text.splitlines(), 1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = ENTRY_RE.match(stripped)
        if not m:
            errors.append(f"{source}:{lineno}: invalid entry {stripped!r}")
            continue
        forbidden = bool(m.group("minus"))
        reason = m.group("reason")  # None | "deps" | "explicit"
        name = m.group("name")
        if forbidden and reason:
            errors.append(f"{source}:{lineno}: '-pkg:{reason}' is not meaningful")
            continue
        kind = "forbidden" if forbidden else "required"
        if name in seen and seen[name] != kind:
            errors.append(f"{source}:{lineno}: {name!r} is both required and forbidden")
            continue
        # Duplicates within a single rendered block are OK across sections;
        # the *kind* (and last-seen reason) is what matters. Last-write-wins.
        seen[name] = kind
        entries.append(Entry(name=name, forbidden=forbidden, reason=reason))

    return entries, errors


def assemble_from_entries(
    entries: list[Entry],
) -> tuple[dict[str, str | None], set[str]]:
    """Reduce ordered entries into (required, forbidden).

    `required` maps name → reason (None | "deps" | "explicit"). A later
    entry overrides an earlier one with the same name (e.g. `pkg:deps` in
    a host section overrides a bare `pkg` from the common section, and
    `-pkg` cancels a prior `pkg`).
    """
    required: dict[str, str | None] = {}
    forbidden: set[str] = set()
    for e in entries:
        if e.forbidden:
            forbidden.add(e.name)
            required.pop(e.name, None)
        else:
            required[e.name] = e.reason
            forbidden.discard(e.name)
    return required, forbidden


# ---- pacman querying ---------------------------------------------------


@dataclass
class PacmanState:
    installed: set[str]
    # provided_name -> set of installed packages that provide it
    providers: dict[str, set[str]]
    # name -> raw "Install Reason" string
    reasons: dict[str, str]
    # name -> set of installed packages that depend on it (live reverse deps,
    # excluding optdepends)
    required_by: dict[str, set[str]]


def query_pacman() -> PacmanState:
    """Single-shot `pacman -Qi` parse."""
    out = subprocess.check_output(["pacman", "-Qi"], text=True)
    installed: set[str] = set()
    providers: dict[str, set[str]] = {}
    reasons: dict[str, str] = {}
    required_by: dict[str, set[str]] = {}
    current: dict[str, str] = {}

    def flush() -> None:
        name = current.get("Name")
        if not name:
            return
        installed.add(name)
        provs = current.get("Provides", "None")
        if provs and provs != "None":
            for p in provs.split():
                pname = p.split("=", 1)[0]
                providers.setdefault(pname, set()).add(name)
        reasons[name] = current.get("Install Reason", "")
        rb = current.get("Required By", "None")
        if rb and rb != "None":
            required_by[name] = set(rb.split())

    for line in out.splitlines():
        if not line.strip():
            flush()
            current = {}
            continue
        if " : " in line:
            key, _, value = line.partition(" : ")
            current[key.strip()] = value.strip()
    flush()
    return PacmanState(
        installed=installed,
        providers=providers,
        reasons=reasons,
        required_by=required_by,
    )


def compute_plan() -> Plan:
    rendered = render_manifest()
    entries, errors = parse_rendered(rendered, source=str(MANIFEST))
    if errors:
        raise SystemExit("\n".join(errors))
    required, forbidden = assemble_from_entries(entries)

    pac = query_pacman()
    installed, providers, reasons = pac.installed, pac.providers, pac.reasons

    # Forbidden + installed packages are removal candidates. Iteratively
    # demote any whose live reverse-deps (after accounting for what we're
    # already removing) are non-empty: we'd rather warn than break the
    # system. Iterate because demoting one can re-block another.
    candidates = sorted(forbidden & installed)
    removing: set[str] = set(candidates)
    skipped: dict[str, set[str]] = {}
    while True:
        progress = False
        for name in candidates:
            if name not in removing:
                continue
            blockers = pac.required_by.get(name, set()) - removing
            if blockers:
                removing.discard(name)
                skipped[name] = blockers
                progress = True
        if not progress:
            break

    to_remove = sorted(removing)
    skipped_remove = sorted((n, sorted(b)) for n, b in skipped.items())
    removed = removing  # alias for satisfied()

    def satisfied(name: str) -> bool:
        if name in installed and name not in removed:
            return True
        return bool(providers.get(name, set()) - removed)

    missing = {n for n in required if not satisfied(n)}
    to_install_default = sorted(n for n in missing if required[n] is None)
    to_install_asdeps = sorted(n for n in missing if required[n] == "deps")
    to_install_asexplicit = sorted(n for n in missing if required[n] == "explicit")

    # Flips only happen for entries with an explicit opinion; bare `pkg`
    # leaves the install reason untouched.
    to_flip_asdeps = sorted(
        n
        for n, want in required.items()
        if want == "deps"
        and n in installed
        and n not in missing
        and reasons.get(n, "").startswith("Explicitly installed")
    )
    to_flip_asexplicit = sorted(
        n
        for n, want in required.items()
        if want == "explicit"
        and n in installed
        and n not in missing
        and reasons.get(n, "").startswith("Installed as a dependency")
    )

    return Plan(
        to_remove=to_remove,
        to_install_default=to_install_default,
        to_install_asdeps=to_install_asdeps,
        to_install_asexplicit=to_install_asexplicit,
        to_flip_asdeps=to_flip_asdeps,
        to_flip_asexplicit=to_flip_asexplicit,
        skipped_remove=skipped_remove,
    )


# ---- subcommands -------------------------------------------------------


def cmd_check(_args: argparse.Namespace) -> int:
    """Validate manifest syntax against the rendered output for this host.

    No reformatting, no sort enforcement — package order in the source
    template is the user's call.
    """
    any_error = False
    try:
        rendered = render_manifest()
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 1

    entries, errs = parse_rendered(rendered, source=str(MANIFEST))
    for e in errs:
        print(e, file=sys.stderr)
    if errs:
        any_error = True

    # Surface any name that ends up both required and forbidden after
    # reduction (shouldn't happen — assemble() handles last-wins — but
    # cheap to guard).
    required, forbidden = assemble_from_entries(entries)
    overlap = set(required) & forbidden
    if overlap:
        print(
            f"{MANIFEST}: rendered set has required ∩ forbidden = "
            f"{sorted(overlap)}",
            file=sys.stderr,
        )
        any_error = True

    return 1 if any_error else 0


def cmd_plan(_args: argparse.Namespace) -> int:
    plan = compute_plan()
    host = os.uname().nodename
    if plan.is_empty():
        print(f"pkgsync: nothing to do for {host}")
        return 0
    print(f"pkgsync · {host}")
    print(plan.human_summary())
    print()
    print(plan.shell_command())
    return 0


def cmd_apply(_args: argparse.Namespace) -> int:
    plan = compute_plan()
    for w in plan.warnings():
        print(f"pkgsync: WARNING {w}", file=sys.stderr)
    if not plan.has_actions():
        return 0
    cmd = plan.shell_command()
    print(cmd, file=sys.stderr)
    return subprocess.call(["bash", "-o", "pipefail", "-c", cmd])


def _notify(body: str, *, urgency: str = "normal") -> None:
    if shutil.which("notify-send"):
        subprocess.call(
            ["notify-send", "-a", "pkgsync", "-u", urgency, "pkgsync", body]
        )
    else:
        print(f"pkgsync: {body}", file=sys.stderr)


def _has_display() -> bool:
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


def _action_count(plan: Plan) -> int:
    return (
        len(plan.to_remove)
        + len(plan.to_install_default)
        + len(plan.to_install_asdeps)
        + len(plan.to_install_asexplicit)
        + len(plan.to_flip_asdeps)
        + len(plan.to_flip_asexplicit)
    )


def _dispatch_detached() -> int:
    """Re-run ourselves as a one-off transient --user systemd unit so the
    GUI survives the parent (chezmoi apply) returning. systemd-run picks
    a fresh `run-rXXXX.service` name; --collect garbage-collects it on
    exit. The detached process re-enters cmd_gui with PKGSYNC_DETACHED=1
    set and proceeds straight to yad → xdg-terminal-exec."""
    if not shutil.which("systemd-run"):
        print(
            "pkgsync: systemd-run not found; running GUI in foreground", file=sys.stderr
        )
        os.environ["PKGSYNC_DETACHED"] = "1"
        return cmd_gui(argparse.Namespace())

    rc = subprocess.call(
        [
            "systemd-run",
            "--user",
            "--collect",
            "--description=pkgsync: declarative package sync",
            "--setenv=PKGSYNC_DETACHED=1",
            "python3",
            str(Path(__file__).resolve()),
            "gui",
        ],
        stdin=subprocess.DEVNULL,
    )
    if rc != 0:
        print("pkgsync: dispatch failed", file=sys.stderr)
    return rc


def cmd_gui(_args: argparse.Namespace) -> int:
    plan = compute_plan()
    host = os.uname().nodename

    # Warnings always go to stderr so chezmoi-apply output surfaces them.
    for w in plan.warnings():
        print(f"pkgsync: WARNING {w}", file=sys.stderr)

    if not plan.has_actions():
        kept = f", {len(plan.skipped_remove)} kept" if plan.skipped_remove else ""
        print(f"pkgsync: clean ({host}{kept})", flush=True)
        return 0

    n = _action_count(plan)
    detached = os.environ.get("PKGSYNC_DETACHED") == "1"

    if not detached:
        if not _has_display():
            print(
                f"pkgsync: {n} change(s) pending on {host} but no desktop "
                "session; run `pkgsync plan` to inspect, `pkgsync apply` "
                "to execute",
                file=sys.stderr,
            )
            return 0
        print(f"pkgsync: dispatching {n} change(s) on {host} to GUI…", flush=True)
        return _dispatch_detached()

    # Detached path: pop yad → exec into xdg-terminal-exec.
    for tool in ("yad", "xdg-terminal-exec"):
        if not shutil.which(tool):
            _notify(
                f"{tool} missing — install it (paru -S {tool}) to use the GUI flow",
                urgency="critical",
            )
            print(plan.shell_command(), file=sys.stderr)
            return 1

    header = ["#!/usr/bin/env bash"]
    for w in plan.warnings():
        header.append(f"# WARNING: {w}")
    if plan.warnings():
        header.append("#")
    header.append("# Edit at will. Lines joined with && abort on first failure.")
    initial = "\n".join(header) + "\n" + plan.shell_command() + "\n"
    fd, edit_path = tempfile.mkstemp(suffix=".sh", prefix="pkgsync.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(initial)

        result = subprocess.run(
            [
                "yad",
                "--text-info",
                "--editable",
                "--title",
                f"pkgsync · {host}",
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
                '  notify-send -a pkgsync -u low pkgsync "Sync complete on $(hostname)"\n'
            )
            f.write("else\n")
            f.write(
                '  notify-send -a pkgsync -u critical pkgsync "Sync failed (exit $rc) on $(hostname)"\n'
            )
            f.write("fi\n")
            f.write('echo\nread -n1 -r -s -p "Press any key to close…"\n')
            f.write('exit "$rc"\n')
        os.chmod(edit_path, 0o755)
    except Exception:
        if os.path.exists(edit_path):
            os.unlink(edit_path)
        raise

    os.execvp("xdg-terminal-exec", ["xdg-terminal-exec", edit_path])


DESCRIPTION = (
    "Declarative package management for Arch dotfiles. Reads "
    "pkgsync/packages.txt.tmpl, renders it for the current host via "
    "`chezmoi execute-template --init`, and computes a plan of paru "
    "actions (install / remove / reason flip)."
)

EPILOG = """\
Manifest syntax (one entry per line; blanks, '#' comments, and chezmoi
template control lines are ignored):

  pkg            required; install reason left untouched if present
  pkg:explicit   required and marked --asexplicit (flipped if needed)
  pkg:deps       required and marked --asdeps     (flipped if needed)
  -pkg           forbidden; cancels a prior `pkg` from a section above

Anything unmentioned is left alone. Provides-aware: an installed
ironbar-git satisfies a required `ironbar`; pair `-ironbar-git` with
`ironbar` to force the non-AUR variant. Last entry wins on conflicts.

Default subcommand is `gui` (used by the chezmoi run_onchange launcher).
"""


def main() -> int:
    p = argparse.ArgumentParser(
        prog="pkgsync",
        description=DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = p.add_subparsers(dest="cmd", metavar="{check,plan,apply,gui}")

    pc = sub.add_parser("check", help="validate manifest syntax (no rewrites)")
    pc.set_defaults(func=cmd_check)

    pp = sub.add_parser("plan", help="print the effective plan; no changes")
    pp.set_defaults(func=cmd_plan)

    pa = sub.add_parser(
        "apply", help="run the plan inline (inherits tty for paru/sudo prompts)"
    )
    pa.set_defaults(func=cmd_apply)

    pg = sub.add_parser(
        "gui",
        help="confirm via yad, dispatch into xdg-terminal-exec (default)",
    )
    pg.set_defaults(func=cmd_gui)

    args = p.parse_args()
    if not args.cmd:
        args = p.parse_args(["gui"])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main() or 0)
