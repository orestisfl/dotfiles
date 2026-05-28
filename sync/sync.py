#!/usr/bin/env python3
from __future__ import annotations

import argparse
import filecmp
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Protocol

SYNC_DIR = Path(__file__).resolve().parent
PACKAGES_MANIFEST = SYNC_DIR / "packages.txt.tmpl"
UNITS_MANIFEST = SYNC_DIR / "units.txt.tmpl"
# Chezmoi-rendered tree of files that ship to root-owned destinations under /.
# Each file's path under STAGING_DIR mirrors its install path, so
# STAGING_DIR/etc/foo.conf → /etc/foo.conf.
STAGING_DIR = Path.home() / ".local" / "share" / "root-staging"


class ReconcilePlan(Protocol):
    """Shared shape of Plan / EtcPlan / UnitPlan / CombinedPlan.

    Plans are dumb data containers built by `compute_*_plan()` and consumed
    by `_run_plan` / `_run_apply` / `_run_gui`. Mutation is one-shot during
    construction; everything downstream is read-only.
    """

    def has_actions(self) -> bool: ...
    def is_empty(self) -> bool: ...
    @property
    def action_count(self) -> int: ...
    def clean_extras(self) -> list[str]: ...
    def warnings(self) -> list[str]: ...
    def shell_command(self) -> str: ...
    def human_summary(self) -> str: ...


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

    @property
    def action_count(self) -> int:
        return (
            len(self.to_remove)
            + len(self.to_install_default)
            + len(self.to_install_asdeps)
            + len(self.to_install_asexplicit)
            + len(self.to_flip_asdeps)
            + len(self.to_flip_asexplicit)
        )

    def clean_extras(self) -> list[str]:
        return [f"{len(self.skipped_remove)} kept"] if self.skipped_remove else []

    def warnings(self) -> list[str]:
        return [
            f"keeping {n} (still required by: {', '.join(blockers)})"
            for n, blockers in self.skipped_remove
        ]

    def shell_command(self) -> str:
        # ENTRY_RE already constrains names to a shell-safe charset, but
        # quote defensively in case the regex is ever relaxed.
        parts: list[str] = []
        if self.to_remove:
            parts.append(f"paru -Rns --noconfirm {shlex.join(self.to_remove)}")
        if self.to_install_default:
            parts.append(
                f"paru -S --needed --noconfirm {shlex.join(self.to_install_default)}"
            )
        if self.to_install_asdeps:
            parts.append(
                f"paru -S --needed --asdeps --noconfirm {shlex.join(self.to_install_asdeps)}"
            )
        if self.to_install_asexplicit:
            parts.append(
                f"paru -S --needed --asexplicit --noconfirm {shlex.join(self.to_install_asexplicit)}"
            )
        if self.to_flip_asdeps:
            parts.append(f"paru -D --asdeps {shlex.join(self.to_flip_asdeps)}")
        if self.to_flip_asexplicit:
            parts.append(f"paru -D --asexplicit {shlex.join(self.to_flip_asexplicit)}")
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


def render_manifest(path: Path = PACKAGES_MANIFEST) -> str:
    """Render the manifest via `chezmoi execute-template --init`."""
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


def _strip_manifest_line(raw: str) -> str:
    """Drop `# trailing comments` and surrounding whitespace.

    Package and unit names never contain '#', so split is unambiguous.
    Returns '' for blank/comment-only lines.
    """
    return raw.split("#", 1)[0].strip()


def parse_rendered(
    text: str, source: str = "<rendered>"
) -> tuple[list[Entry], list[str]]:
    """Parse fully-rendered manifest text. Returns (entries, errors)."""
    entries: list[Entry] = []
    errors: list[str] = []
    seen: dict[str, str] = {}

    for lineno, raw in enumerate(text.splitlines(), 1):
        stripped = _strip_manifest_line(raw)
        if not stripped:
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


def _load_packages() -> tuple[list[Entry], list[str]]:
    """Render + parse the packages manifest. Mirror of `_load_units` so the
    `check` / `apply` / GUI commands share one error-handling shape."""
    try:
        rendered = render_manifest()
    except SystemExit as exc:
        return [], [str(exc)]
    return parse_rendered(rendered, source=str(PACKAGES_MANIFEST))


def compute_plan() -> Plan:
    entries, errors = _load_packages()
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
    """Validate manifest syntax against the rendered output for this host."""
    _, errs = _load_packages()
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


def _label_prefix(domain: str) -> str:
    """`sync` for the top-level combined orchestrator, `sync <domain>` otherwise."""
    return "sync" if domain == "all" else f"sync {domain}"


def _run_plan(domain: str, plan: ReconcilePlan) -> int:
    prefix = _label_prefix(domain)
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


def _run_apply(domain: str, plan: ReconcilePlan) -> int:
    prefix = _label_prefix(domain)
    for w in plan.warnings():
        print(f"{prefix}: WARNING {w}", file=sys.stderr)
    if not plan.has_actions():
        return 0
    cmd = plan.shell_command()
    print(cmd, file=sys.stderr)
    return subprocess.call(["bash", "-o", "pipefail", "-c", cmd])


def cmd_plan(_args: argparse.Namespace) -> int:
    return _run_plan("packages", compute_plan())


def cmd_apply(_args: argparse.Namespace) -> int:
    return _run_apply("packages", compute_plan())


def _notify(body: str, *, urgency: str = "normal") -> None:
    if shutil.which("notify-send"):
        subprocess.call(["notify-send", "-a", "sync", "-u", urgency, "sync", body])
    else:
        print(f"sync: {body}", file=sys.stderr)


def _has_display() -> bool:
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


def _dispatch_detached(domain: str) -> int:
    """Re-run ourselves as a one-off transient --user systemd unit so the
    GUI survives the parent (chezmoi apply) returning. systemd-run picks
    a fresh `run-rXXXX.service` name; --collect garbage-collects it on
    exit. The detached process re-enters the matching `cmd_*_gui` with
    SYNC_DETACHED=1 set and proceeds straight to yad → xdg-terminal-exec.

    `domain` is one of: "packages", "etc", "units", or "all" (top-level
    combined GUI). For "all" the child is invoked as `sync gui`; for the
    individual domains it's `sync <domain> gui`.
    """
    child_args = ["gui"] if domain == "all" else [domain, "gui"]
    if not shutil.which("systemd-run"):
        print("sync: systemd-run not found; running GUI in foreground", file=sys.stderr)
        os.environ["SYNC_DETACHED"] = "1"
        return _GUI_HANDLERS[domain](argparse.Namespace())

    rc = subprocess.call(
        [
            "systemd-run",
            "--user",
            "--collect",
            f"--description=sync: declarative {domain} reconcile",
            "--setenv=SYNC_DETACHED=1",
            "python3",
            str(Path(__file__).resolve()),
            *child_args,
        ],
        stdin=subprocess.DEVNULL,
    )
    if rc != 0:
        print(f"sync: dispatch {domain} failed", file=sys.stderr)
    return rc


def _run_gui(domain: str, plan: ReconcilePlan) -> int:
    """Shared yad → xdg-terminal-exec flow for any ReconcilePlan."""
    host = os.uname().nodename
    # The "all" domain is invoked as `sync gui` / `sync plan` from the CLI;
    # don't say "sync all" in user-facing messages.
    label = _label_prefix(domain)
    warnings = plan.warnings()

    # Warnings always go to stderr so chezmoi-apply output surfaces them.
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
        print(
            f"{label}: dispatching {n} change(s) on {host} to GUI…",
            flush=True,
        )
        return _dispatch_detached(domain)

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
    except Exception:
        if os.path.exists(edit_path):
            os.unlink(edit_path)
        raise

    os.execvp("xdg-terminal-exec", ["xdg-terminal-exec", edit_path])


def cmd_gui(_args: argparse.Namespace) -> int:
    return _run_gui("packages", compute_plan())


# ---- etc (root-owned files staged under ~/.local/share/root-staging) ---


@dataclass(frozen=True)
class _EtcReloadRule:
    prefix: str  # destination path prefix that triggers this reload
    command: str  # bash command appended to the pkexec batch
    label: str  # short tag for `human_summary` (no shell quoting)


# Order preserved across `shell_command` / `human_summary`. Reload commands
# run as root inside the etc pkexec batch, so they don't trigger their own
# polkit prompts.
_ETC_RELOAD_RULES = (
    _EtcReloadRule("/etc/systemd/system/", "systemctl daemon-reload", "daemon-reload"),
    _EtcReloadRule(
        "/etc/tlp.d/",
        "systemctl try-reload-or-restart tlp.service",
        "tlp reload",
    ),
    _EtcReloadRule(
        "/etc/NetworkManager/conf.d/",
        "systemctl reload NetworkManager",
        "NetworkManager reload",
    ),
)


def _etc_reloads(dests: list[Path]) -> list[_EtcReloadRule]:
    return [
        r for r in _ETC_RELOAD_RULES if any(str(d).startswith(r.prefix) for d in dests)
    ]


@dataclass
class EtcPlan:
    # (src under STAGING_DIR, dest under /). Order preserved (sorted by src).
    to_install: list[tuple[Path, Path]] = field(default_factory=list)

    def has_actions(self) -> bool:
        return bool(self.to_install)

    def is_empty(self) -> bool:
        return not self.has_actions()

    @property
    def action_count(self) -> int:
        return len(self.to_install)

    def clean_extras(self) -> list[str]:
        return []

    def warnings(self) -> list[str]:
        return []

    @property
    def _dests(self) -> list[Path]:
        return [dest for _, dest in self.to_install]

    def shell_command(self) -> str:
        # All installs + reloads run as root in a single pkexec — one polkit
        # prompt for the whole batch, matching paru's `Sudo = pkexec` flow.
        if not self.to_install:
            return ""
        cmds = [
            f"install -Dm644 {shlex.quote(str(src))} {shlex.quote(str(dest))}"
            for src, dest in self.to_install
        ]
        cmds.extend(r.command for r in _etc_reloads(self._dests))
        return f"pkexec sh -c {shlex.quote(' && '.join(cmds))}"

    def human_summary(self) -> str:
        lines = [f"  ~ {dest}" for dest in self._dests]
        labels = [r.label for r in _etc_reloads(self._dests)]
        if labels:
            lines.append(f"  (then: {', '.join(labels)})")
        return "\n".join(lines)


def compute_etc_plan() -> EtcPlan:
    plan = EtcPlan()
    if not STAGING_DIR.is_dir():
        return plan
    for src in sorted(STAGING_DIR.rglob("*")):
        if not src.is_file():
            continue
        rel = src.relative_to(STAGING_DIR)
        dest = Path("/") / rel
        try:
            if dest.is_file() and filecmp.cmp(src, dest, shallow=False):
                continue
        except OSError:
            # `/` is root-owned; permission errors mean we can't confirm
            # equality, so assume drift and let the pkexec batch overwrite.
            pass
        plan.to_install.append((src, dest))
    return plan


def cmd_etc_check(_args: argparse.Namespace) -> int:
    # No manifest to validate; report the staging dir state for visibility.
    if not STAGING_DIR.is_dir():
        print(f"sync etc: staging dir {STAGING_DIR} does not exist (nothing to do)")
        return 0
    n = sum(1 for p in STAGING_DIR.rglob("*") if p.is_file())
    print(f"sync etc: {n} staged file(s) under {STAGING_DIR}")
    return 0


def cmd_etc_plan(_args: argparse.Namespace) -> int:
    return _run_plan("etc", compute_etc_plan())


def cmd_etc_apply(_args: argparse.Namespace) -> int:
    return _run_apply("etc", compute_etc_plan())


def cmd_etc_gui(_args: argparse.Namespace) -> int:
    return _run_gui("etc", compute_etc_plan())


# ---- units -------------------------------------------------------------


# +unit | +unit:user | -unit | -unit:user. Names must include the unit suffix
# (.service / .timer / .socket / ...) and may use the `name@instance.suffix`
# form.
UNIT_ENTRY_RE = re.compile(
    r"^(?P<sign>[+-])(?P<name>[a-zA-Z0-9@._:-]+\.[a-zA-Z]+)(?::(?P<scope>user|system))?$"
)


@dataclass(frozen=True)
class UnitEntry:
    name: str
    scope: str  # "system" | "user"
    enable: bool  # True = ensure enabled, False = ensure disabled


def parse_units(
    text: str, source: str = "<rendered>"
) -> tuple[list[UnitEntry], list[str]]:
    entries: list[UnitEntry] = []
    errors: list[str] = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        stripped = _strip_manifest_line(raw)
        if not stripped:
            continue
        m = UNIT_ENTRY_RE.match(stripped)
        if not m:
            errors.append(f"{source}:{lineno}: invalid entry {stripped!r}")
            continue
        scope = m.group("scope") or "system"
        entries.append(
            UnitEntry(
                name=m.group("name"),
                scope=scope,
                enable=(m.group("sign") == "+"),
            )
        )
    return entries, errors


def _load_units() -> tuple[list[UnitEntry], list[str]]:
    """Render + parse the units manifest and detect +/- conflicts.

    Returns (entries, errors). Errors are stringified for stderr printing
    and cover render failures, parse failures, and same (name, scope)
    declared as both enabled and disabled.
    """
    try:
        rendered = render_manifest(UNITS_MANIFEST)
    except SystemExit as exc:
        return [], [str(exc)]
    entries, errs = parse_units(rendered, source=str(UNITS_MANIFEST))
    seen: dict[tuple[str, str], bool] = {}
    conflicts: set[tuple[str, str]] = set()
    for e in entries:
        key = (e.name, e.scope)
        if key in seen and seen[key] != e.enable:
            conflicts.add(key)
        seen[key] = e.enable
    for name, scope in sorted(conflicts):
        errs.append(f"{UNITS_MANIFEST}: {name} ({scope}) is both enabled and disabled")
    return entries, errs


# is-enabled states (systemctl(1)) we treat as "already in the desired state"
# when the manifest asks for the unit to be enabled. `static` units have no
# [Install] section so they can't be enabled; they're activated by deps or
# socket activation. `generated`/`linked`/`alias` are pre-wired equivalents.
_ENABLE_OK_STATES = frozenset(
    {"enabled", "enabled-runtime", "alias", "static", "generated", "linked"}
)
# States that we can flip with `systemctl enable`.
_ENABLEABLE_STATES = frozenset({"disabled", "indirect", "transient"})
# States that count as "actually enabled" — anything else can't be disabled
# meaningfully (masked/static/not-found).
_ACTIVE_ENABLE_STATES = frozenset({"enabled", "enabled-runtime", "alias"})


@dataclass
class UnitPlan:
    to_enable_system: list[str] = field(default_factory=list)
    to_disable_system: list[str] = field(default_factory=list)
    to_enable_user: list[str] = field(default_factory=list)
    to_disable_user: list[str] = field(default_factory=list)
    # (name, scope, reason) — manifest asked for enable but state forbids it
    # (e.g. masked, not-found).
    skipped: list[tuple[str, str, str]] = field(default_factory=list)

    def has_actions(self) -> bool:
        return bool(
            self.to_enable_system
            or self.to_disable_system
            or self.to_enable_user
            or self.to_disable_user
        )

    def is_empty(self) -> bool:
        return not (self.has_actions() or self.skipped)

    @property
    def action_count(self) -> int:
        return (
            len(self.to_enable_system)
            + len(self.to_disable_system)
            + len(self.to_enable_user)
            + len(self.to_disable_user)
        )

    def clean_extras(self) -> list[str]:
        return [f"{len(self.skipped)} skipped"] if self.skipped else []

    def warnings(self) -> list[str]:
        return [
            f"skipping {n} ({scope}): {reason}" for n, scope, reason in self.skipped
        ]

    def shell_command(self) -> str:
        # System-scope systemctl talks to systemd over DBus and triggers the
        # user's polkit agent — same GUI auth path as `paru` (configured
        # with `Sudo = pkexec`). No sudo wrapper needed; on a TTY without
        # an agent the action fails with "access denied" instead.
        parts: list[str] = []
        if self.to_disable_user:
            parts.append(
                f"systemctl --user disable --now {shlex.join(self.to_disable_user)}"
            )
        if self.to_enable_user:
            parts.append(
                f"systemctl --user enable --now {shlex.join(self.to_enable_user)}"
            )
        if self.to_disable_system:
            parts.append(
                f"systemctl disable --now {shlex.join(self.to_disable_system)}"
            )
        if self.to_enable_system:
            parts.append(f"systemctl enable --now {shlex.join(self.to_enable_system)}")
        return " \\\n  && ".join(parts)

    def human_summary(self) -> str:
        lines: list[str] = []
        for n in self.to_disable_system:
            lines.append(f"  - {n}")
        for n in self.to_enable_system:
            lines.append(f"  + {n}")
        for n in self.to_disable_user:
            lines.append(f"  - {n}  (user)")
        for n in self.to_enable_user:
            lines.append(f"  + {n}  (user)")
        for n, scope, reason in self.skipped:
            tag = " (user)" if scope == "user" else ""
            lines.append(f"  ! {n}{tag}  ({reason})")
        return "\n".join(lines)


def systemctl_state(name: str, scope: str) -> str:
    """Return systemctl's unit-file state for `name` in the given scope.

    Maps any failure (missing unit, unreadable, etc.) to 'not-found' so the
    planner can warn instead of crashing.
    """
    scope_args = ["--user"] if scope == "user" else []
    proc = subprocess.run(
        ["systemctl", *scope_args, "is-enabled", name],
        capture_output=True,
        text=True,
    )
    return proc.stdout.strip() or "not-found"


def compute_units_plan() -> UnitPlan:
    entries, errs = _load_units()
    if errs:
        raise SystemExit("\n".join(errs))

    # Reduce to last-wins per (name, scope); conflicts already errored in
    # _load_units, so any duplicates here agree.
    desired: dict[tuple[str, str], bool] = {}
    for e in entries:
        desired[(e.name, e.scope)] = e.enable

    plan = UnitPlan()
    for (name, scope), enable in desired.items():
        state = systemctl_state(name, scope)
        if enable:
            if state in _ENABLE_OK_STATES:
                continue
            if state in _ENABLEABLE_STATES:
                (
                    plan.to_enable_user if scope == "user" else plan.to_enable_system
                ).append(name)
            else:
                plan.skipped.append((name, scope, f"cannot enable (state: {state})"))
        else:
            if state in _ACTIVE_ENABLE_STATES:
                (
                    plan.to_disable_user if scope == "user" else plan.to_disable_system
                ).append(name)
            # else: already disabled / static / not-found — nothing to do.
    return plan


def cmd_units_check(_args: argparse.Namespace) -> int:
    _, errs = _load_units()
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


def cmd_units_plan(_args: argparse.Namespace) -> int:
    return _run_plan("units", compute_units_plan())


def cmd_units_apply(_args: argparse.Namespace) -> int:
    return _run_apply("units", compute_units_plan())


def cmd_units_gui(_args: argparse.Namespace) -> int:
    return _run_gui("units", compute_units_plan())


# ---- combined orchestrator (top-level) ---------------------------------


@dataclass
class CombinedPlan:
    """Aggregate of (label, plan) pairs in dependency order.

    Implements the same surface as Plan / UnitPlan / EtcPlan (the
    ReconcilePlan protocol) so it can flow through _run_gui / _run_plan /
    _run_apply unchanged. shell_command chains each non-empty subplan with
    `&&`, so a failure (or aborted prompt) halts the rest.
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


def _compute_all() -> CombinedPlan:
    # Order matters: install packages first (so e.g. ufw exists), then drop
    # root-owned files (so unit files are in /etc/systemd/system), then
    # enable/disable units.
    return CombinedPlan(
        parts=[
            ("packages", compute_plan()),
            ("etc", compute_etc_plan()),
            ("units", compute_units_plan()),
        ]
    )


def cmd_all_check(_args: argparse.Namespace) -> int:
    rc = 0
    rc |= cmd_check(_args)
    rc |= cmd_etc_check(_args)
    rc |= cmd_units_check(_args)
    return rc


def cmd_all_plan(_args: argparse.Namespace) -> int:
    return _run_plan("all", _compute_all())


def cmd_all_apply(_args: argparse.Namespace) -> int:
    return _run_apply("all", _compute_all())


def cmd_all_gui(_args: argparse.Namespace) -> int:
    return _run_gui("all", _compute_all())


DESCRIPTION = (
    "Declarative reconciler for Arch dotfiles. Three subcomponents run in "
    "dependency order on `sync gui` / `sync apply`: packages (paru), etc "
    "(root-owned files staged under ~/.local/share/root-staging), units "
    "(systemctl, system + --user)."
)

EPILOG = """\
Top-level (run all three in dependency order: packages → etc → units):

  sync check        validate manifests + report staging state
  sync plan         print combined plan for this host
  sync apply        execute inline (polkit / pkexec / paru prompts as needed)
  sync gui          single yad review, then xdg-terminal-exec the chain
  sync              alias for `sync gui` (chezmoi run_onchange entry point)

Per-domain subcommands take the same {check, plan, apply, gui} verbs:

  sync packages …   pacman/paru install/remove/reason-flip (packages.txt.tmpl)
  sync etc …        install root-owned files from ~/.local/share/root-staging
  sync units …      systemctl enable/disable, system + --user (units.txt.tmpl)

Packages manifest syntax (one entry per line; blanks and '#' comments ignored):

  pkg            required; install reason left untouched if present
  pkg:explicit   required and marked --asexplicit (flipped if needed)
  pkg:deps       required and marked --asdeps     (flipped if needed)
  -pkg           forbidden; cancels a prior `pkg` from a section above

Units manifest syntax:

  +unit.svc          ensure enabled (system scope)
  +unit.svc:user     ensure enabled (--user scope)
  -unit.svc          ensure disabled (system)
  -unit.svc:user     ensure disabled (--user)
"""


_GUI_HANDLERS: dict[str, Callable[[argparse.Namespace], int]] = {
    "packages": cmd_gui,
    "etc": cmd_etc_gui,
    "units": cmd_units_gui,
    "all": cmd_all_gui,
}


_Verb = Callable[[argparse.Namespace], int]


def _add_verbs(
    sub: argparse._SubParsersAction,
    *,
    check: _Verb,
    plan: _Verb,
    apply: _Verb,
    gui: _Verb,
    check_help: str,
    plan_help: str,
    apply_help: str,
) -> None:
    pp = sub.add_parser("check", help=check_help)
    pp.set_defaults(func=check)
    pp = sub.add_parser("plan", help=plan_help)
    pp.set_defaults(func=plan)
    pp = sub.add_parser("apply", help=apply_help)
    pp.set_defaults(func=apply)
    pp = sub.add_parser("gui", help="confirm via yad, dispatch into xdg-terminal-exec")
    pp.set_defaults(func=gui)


def main() -> int:
    p = argparse.ArgumentParser(
        prog="sync",
        description=DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    top = p.add_subparsers(
        dest="top", metavar="{check,plan,apply,gui,packages,etc,units}"
    )

    # Top-level verbs run all three subcomponents in order.
    _add_verbs(
        top,
        check=cmd_all_check,
        plan=cmd_all_plan,
        apply=cmd_all_apply,
        gui=cmd_all_gui,
        check_help="validate every subcomponent",
        plan_help="print the combined plan for all subcomponents",
        apply_help="run all subcomponents inline (sequential, halts on first failure)",
    )

    pkg = top.add_parser("packages", help="declarative package management")
    _add_verbs(
        pkg.add_subparsers(dest="cmd", metavar="{check,plan,apply,gui}"),
        check=cmd_check,
        plan=cmd_plan,
        apply=cmd_apply,
        gui=cmd_gui,
        check_help="validate packages manifest syntax",
        plan_help="print the effective package plan",
        apply_help="run the plan inline (inherits tty for paru prompts)",
    )

    etc = top.add_parser("etc", help="root-owned files staged under root-staging/")
    _add_verbs(
        etc.add_subparsers(dest="cmd", metavar="{check,plan,apply,gui}"),
        check=cmd_etc_check,
        plan=cmd_etc_plan,
        apply=cmd_etc_apply,
        gui=cmd_etc_gui,
        check_help="report staging dir contents (no manifest to validate)",
        plan_help="print files that differ between staging and /",
        apply_help="copy staged files into / via pkexec",
    )

    unt = top.add_parser("units", help="declarative systemd unit management")
    _add_verbs(
        unt.add_subparsers(dest="cmd", metavar="{check,plan,apply,gui}"),
        check=cmd_units_check,
        plan=cmd_units_plan,
        apply=cmd_units_apply,
        gui=cmd_units_gui,
        check_help="validate units manifest syntax",
        plan_help="print the effective unit plan",
        apply_help="enable/disable units inline (polkit prompt via agent)",
    )

    args = p.parse_args()
    # Defaults:
    #   sync                     → sync gui  (chezmoi hook entry point)
    #   sync <packages|etc|units> → that domain's plan
    if not args.top:
        args = p.parse_args(["gui"])
    elif args.top in ("packages", "etc", "units") and not getattr(args, "cmd", None):
        args = p.parse_args([args.top, "plan"])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main() or 0)
