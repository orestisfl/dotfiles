"""Declarative systemd unit management (system + --user scope).

Renders `units.txt.tmpl`, queries each unit's `is-enabled` state, and emits a
`UnitPlan` of enable/disable actions. System-scope systemctl auths via the
user's polkit agent, the same GUI path as paru's `Sudo = pkexec`.
"""

from __future__ import annotations

import re
import shlex
import subprocess
from dataclasses import dataclass, field

from common import SYNC_DIR, load_manifest, manifest_check, strip_manifest_line

UNITS_MANIFEST = SYNC_DIR / "units.txt.tmpl"

# +unit | +unit:user | -unit | -unit:user; name includes the .suffix and may
# be `name@instance.suffix`.
UNIT_ENTRY_RE = re.compile(
    r"^(?P<sign>[+-])(?P<name>[a-zA-Z0-9@._:-]+\.[a-zA-Z]+)(?::(?P<scope>user|system))?$"
)

# is-enabled states already satisfying a requested enable (static/generated/
# linked/alias are pre-wired equivalents that can't be `enable`d).
_ENABLE_OK_STATES = frozenset(
    {"enabled", "enabled-runtime", "alias", "static", "generated", "linked"}
)
# States we can flip with `systemctl enable`.
_ENABLEABLE_STATES = frozenset({"disabled", "indirect", "transient"})
# States that count as "actually enabled" (else disable is a no-op).
_ACTIVE_ENABLE_STATES = frozenset({"enabled", "enabled-runtime", "alias"})


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
        stripped = strip_manifest_line(raw)
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
    """Render + parse the units manifest; errors also flag a (name, scope)
    declared both enabled and disabled.
    """
    entries, errs = load_manifest(UNITS_MANIFEST, parse_units)
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


@dataclass
class UnitPlan:
    to_enable_system: list[str] = field(default_factory=list)
    to_disable_system: list[str] = field(default_factory=list)
    to_enable_user: list[str] = field(default_factory=list)
    to_disable_user: list[str] = field(default_factory=list)
    # (name, scope, reason): enable requested but state forbids it.
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
        # System scope auths via the polkit agent; on a bare TTY it fails
        # with "access denied".
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
    """Unit-file state for `name`; any failure maps to 'not-found'."""
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

    # Last-wins per (name, scope); conflicts already errored in _load_units.
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


def check() -> int:
    return manifest_check(_load_units)
