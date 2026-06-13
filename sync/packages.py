"""Declarative package management (paru/pacman).

Renders `packages.txt.tmpl`, diffs the desired set against the live pacman
database, and emits a `Plan` of installs / removals / install-reason flips.
"""

from __future__ import annotations

import re
import shlex
import subprocess
from dataclasses import dataclass, field

from common import SYNC_DIR, load_manifest, manifest_check, strip_manifest_line

PACKAGES_MANIFEST = SYNC_DIR / "packages.txt.tmpl"

# pkg | pkg:deps | pkg:explicit | -pkg (leading dash = forbidden marker).
ENTRY_RE = re.compile(
    r"^(?P<minus>-)?(?P<name>[a-zA-Z0-9@._+][a-zA-Z0-9@._+-]*)"
    r"(?::(?P<reason>deps|explicit))?$"
)


@dataclass(frozen=True)
class Entry:
    name: str
    forbidden: bool
    # None → leave reason alone; "deps"/"explicit" → mark --asdeps/--asexplicit
    reason: str | None


@dataclass
class Plan:
    to_remove: list[str] = field(default_factory=list)
    to_install_default: list[str] = field(default_factory=list)
    to_install_asdeps: list[str] = field(default_factory=list)
    to_install_asexplicit: list[str] = field(default_factory=list)
    # Reason flips: manifest opinion disagrees with pacman's record.
    to_flip_asdeps: list[str] = field(default_factory=list)
    to_flip_asexplicit: list[str] = field(default_factory=list)
    # Forbidden+installed we declined to remove; (pkg, sorted blockers).
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


def parse_rendered(
    text: str, source: str = "<rendered>"
) -> tuple[list[Entry], list[str]]:
    """Parse fully-rendered manifest text. Returns (entries, errors)."""
    entries: list[Entry] = []
    errors: list[str] = []
    seen: dict[str, str] = {}

    for lineno, raw in enumerate(text.splitlines(), 1):
        stripped = strip_manifest_line(raw)
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
        # Last-write-wins across sections; the kind is what matters.
        seen[name] = kind
        entries.append(Entry(name=name, forbidden=forbidden, reason=reason))

    return entries, errors


def assemble_from_entries(
    entries: list[Entry],
) -> tuple[dict[str, str | None], set[str]]:
    """Reduce ordered entries into (required, forbidden); later entries win
    (host section overrides common, `-pkg` cancels a prior `pkg`).
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
    providers: dict[str, set[str]]  # provided name -> providing packages
    reasons: dict[str, str]  # name -> raw "Install Reason"
    required_by: dict[str, set[str]]  # name -> live reverse deps (no optdepends)


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
    """Render + parse the packages manifest."""
    return load_manifest(PACKAGES_MANIFEST, parse_rendered)


def compute_packages_plan() -> Plan:
    entries, errors = _load_packages()
    if errors:
        raise SystemExit("\n".join(errors))
    required, forbidden = assemble_from_entries(entries)

    pac = query_pacman()
    installed, providers, reasons = pac.installed, pac.providers, pac.reasons

    # Forbidden+installed are removal candidates; iteratively demote any with
    # live reverse-deps (warn rather than break; demoting one can re-block another).
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

    def satisfied(name: str) -> bool:
        if name in installed and name not in removing:
            return True
        return bool(providers.get(name, set()) - removing)

    missing = {n for n in required if not satisfied(n)}
    to_install_default = sorted(n for n in missing if required[n] is None)
    to_install_asdeps = sorted(n for n in missing if required[n] == "deps")
    to_install_asexplicit = sorted(n for n in missing if required[n] == "explicit")

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


def check() -> int:
    """Validate manifest syntax against the rendered output for this host."""
    return manifest_check(_load_packages)
