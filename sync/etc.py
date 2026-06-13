"""Root-owned files staged under ~/.local/share/root-staging.

Each staged file's path mirrors its install path (STAGING_DIR/etc/foo.conf →
/etc/foo.conf); this domain diffs the tree against `/` and installs the drift
(plus matching reload commands) in a single pkexec batch.
"""

from __future__ import annotations

import filecmp
import shlex
from dataclasses import dataclass, field
from pathlib import Path

# Chezmoi-rendered tree of files that ship to root-owned destinations under /.
STAGING_DIR = Path.home() / ".local" / "share" / "root-staging"


@dataclass(frozen=True)
class _EtcReloadRule:
    prefix: str  # destination path prefix that triggers this reload
    command: str  # bash command appended to the pkexec batch
    label: str  # short tag for `human_summary` (no shell quoting)


# Reload commands run as root inside the etc pkexec batch (no extra prompt).
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
        # One pkexec for the whole batch: a single polkit prompt.
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
            # Can't confirm equality (root-owned); assume drift and overwrite.
            pass
        plan.to_install.append((src, dest))
    return plan


def check() -> int:
    # No manifest to validate; report the staging dir state for visibility.
    if not STAGING_DIR.is_dir():
        print(f"sync etc: staging dir {STAGING_DIR} does not exist (nothing to do)")
        return 0
    n = sum(1 for p in STAGING_DIR.rglob("*") if p.is_file())
    print(f"sync etc: {n} staged file(s) under {STAGING_DIR}")
    return 0
