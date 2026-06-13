"""Declarative XDG default applications.

Renders `defaults.txt.tmpl` (`selector = app.desktop`), resolves each selector
to a MIME/browser/terminal target, and emits a `DefaultsPlan` of xdg-mime /
xdg-settings / xdg-terminals.list writes (all in $HOME, no polkit).
"""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from common import SYNC_DIR, load_manifest, manifest_check, strip_manifest_line

DEFAULTS_MANIFEST = SYNC_DIR / "defaults.txt.tmpl"
# shared-mime-info glob db (weight:mimetype:glob); resolves `ext:.foo` → MIME.
MIME_GLOBS2 = Path("/usr/share/mime/globs2")
_XDG_CONFIG_HOME = Path(
    os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
)
# xdg-terminal-exec reads the first installed entry here as the terminal.
XDG_TERMINALS_LIST = _XDG_CONFIG_HOME / "xdg-terminals.list"

# `selector = app.desktop`; desktop-id charset kept shell-safe downstream.
DEFAULTS_ENTRY_RE = re.compile(
    r"^(?P<selector>\S+)\s*=\s*(?P<id>[A-Za-z0-9][A-Za-z0-9._+-]*\.desktop)$"
)
_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*$")
_EXT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+-]*$")
_MIME_RE = re.compile(
    r"^[a-zA-Z0-9][a-zA-Z0-9!#$&^_.+-]*/[a-zA-Z0-9][a-zA-Z0-9!#$&^_.+-]*$"
)


@dataclass(frozen=True)
class DefaultEntry:
    # kind: "mime" (key=MIME, incl. x-scheme-handler/*), "ext" (key=extension,
    # resolved at plan time), or "terminal"/"browser" (key="").
    kind: str
    key: str
    desktop_id: str


def _classify_selector(selector: str) -> tuple[str, str] | None:
    """Map a manifest selector to (kind, key), or None if malformed."""
    if selector in ("terminal", "browser"):
        return (selector, "")
    if selector.startswith("scheme:"):
        name = selector[len("scheme:") :]
        return ("mime", f"x-scheme-handler/{name}") if _SCHEME_RE.match(name) else None
    if selector.startswith("ext:"):
        ext = selector[len("ext:") :].lstrip(".").lower()
        return ("ext", ext) if ext and _EXT_RE.match(ext) else None
    if "/" in selector:
        return ("mime", selector) if _MIME_RE.match(selector) else None
    return None


def parse_defaults(
    text: str, source: str = "<rendered>"
) -> tuple[list[DefaultEntry], list[str]]:
    entries: list[DefaultEntry] = []
    errors: list[str] = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        stripped = strip_manifest_line(raw)
        if not stripped:
            continue
        m = DEFAULTS_ENTRY_RE.match(stripped)
        if not m:
            errors.append(f"{source}:{lineno}: invalid entry {stripped!r}")
            continue
        classified = _classify_selector(m.group("selector"))
        if classified is None:
            errors.append(
                f"{source}:{lineno}: unknown selector {m.group('selector')!r}"
            )
            continue
        kind, key = classified
        entries.append(DefaultEntry(kind=kind, key=key, desktop_id=m.group("id")))
    return entries, errors


def _load_defaults() -> tuple[list[DefaultEntry], list[str]]:
    """Render + parse the defaults manifest."""
    return load_manifest(DEFAULTS_MANIFEST, parse_defaults)


def _load_ext_map() -> dict[str, str]:
    """Parse globs2 `weight:mimetype:*.ext` lines → {ext: mimetype}, highest
    weight wins per extension (ties: first seen)."""
    best: dict[str, tuple[int, str]] = {}
    try:
        text = MIME_GLOBS2.read_text()
    except OSError:
        return {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split(":")
        if len(parts) < 3 or not parts[2].startswith("*."):
            continue
        try:
            weight = int(parts[0])
        except ValueError:
            continue
        ext = parts[2][2:].lower()
        if ext not in best or weight > best[ext][0]:
            best[ext] = (weight, parts[1])
    return {ext: mt for ext, (_, mt) in best.items()}


def _desktop_dirs() -> list[Path]:
    home = Path.home()
    data_home = os.environ.get("XDG_DATA_HOME") or str(home / ".local" / "share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    bases = [data_home, *data_dirs.split(":")]
    # Flatpak exports aren't always in a non-login shell's XDG_DATA_DIRS.
    bases += [
        "/var/lib/flatpak/exports/share",
        str(home / ".local/share/flatpak/exports/share"),
    ]
    dirs = (Path(b) / "applications" for b in bases if b)
    return list(dict.fromkeys(dirs))


def _xdg_mime_default(mimetype: str) -> str:
    proc = subprocess.run(
        ["xdg-mime", "query", "default", mimetype], capture_output=True, text=True
    )
    return proc.stdout.strip()


def _xdg_settings_browser() -> str:
    proc = subprocess.run(
        ["xdg-settings", "get", "default-web-browser"], capture_output=True, text=True
    )
    return proc.stdout.strip()


def _terminal_current() -> str:
    try:
        for raw in XDG_TERMINALS_LIST.read_text().splitlines():
            if entry := strip_manifest_line(raw):
                return entry
    except OSError:
        pass
    return ""


@dataclass
class DefaultsPlan:
    # (mimetype, desired_id, current_id) where current != desired.
    to_set_mime: list[tuple[str, str, str]] = field(default_factory=list)
    terminal: tuple[str, str] | None = None  # (desired, current)
    browser: tuple[str, str] | None = None  # (desired, current)
    # (selector/key, reason) for entries we declined to assert.
    skipped: list[tuple[str, str]] = field(default_factory=list)

    def has_actions(self) -> bool:
        return bool(self.to_set_mime or self.terminal or self.browser)

    def is_empty(self) -> bool:
        return not (self.has_actions() or self.skipped)

    @property
    def action_count(self) -> int:
        return (
            len(self.to_set_mime)
            + (1 if self.terminal else 0)
            + (1 if self.browser else 0)
        )

    def clean_extras(self) -> list[str]:
        return [f"{len(self.skipped)} skipped"] if self.skipped else []

    def warnings(self) -> list[str]:
        return [f"skipping {key}: {reason}" for key, reason in self.skipped]

    def shell_command(self) -> str:
        # Browser first (broad bundle), then explicit MIME defaults so a
        # deliberate `text/html = chromium` wins over the browser macro.
        parts: list[str] = []
        if self.browser:
            parts.append(
                f"xdg-settings set default-web-browser {shlex.quote(self.browser[0])}"
            )
        by_id: dict[str, list[str]] = {}
        for mimetype, desired_id, _cur in self.to_set_mime:
            by_id.setdefault(desired_id, []).append(mimetype)
        for desired_id, types in by_id.items():
            parts.append(
                f"xdg-mime default {shlex.quote(desired_id)} {shlex.join(types)}"
            )
        if self.terminal:
            parts.append(
                "printf '%s\\n' "
                + shlex.quote(self.terminal[0])
                + ' > "${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"'
            )
        return " \\\n  && ".join(parts)

    def human_summary(self) -> str:
        lines: list[str] = []
        if self.browser:
            d, c = self.browser
            lines.append(f"  ~ browser  {d}" + (f"  (was {c})" if c else ""))
        for mimetype, d, c in self.to_set_mime:
            lines.append(f"  ~ {mimetype}  {d}" + (f"  (was {c})" if c else ""))
        if self.terminal:
            d, c = self.terminal
            lines.append(f"  ~ terminal  {d}" + (f"  (was {c})" if c else ""))
        for key, reason in self.skipped:
            lines.append(f"  ! {key}  ({reason})")
        return "\n".join(lines)


def compute_defaults_plan() -> DefaultsPlan:
    entries, errs = _load_defaults()
    if errs:
        raise SystemExit("\n".join(errs))

    # Reduce to desired state, last-wins per resolved key (mirrors packages).
    ext_map: dict[str, str] | None = None
    mime_desired: dict[str, str] = {}
    terminal_id: str | None = None
    browser_id: str | None = None
    skipped: list[tuple[str, str]] = []

    for e in entries:
        if e.kind == "terminal":
            terminal_id = e.desktop_id
        elif e.kind == "browser":
            browser_id = e.desktop_id
        elif e.kind == "mime":
            mime_desired[e.key] = e.desktop_id
        elif e.kind == "ext":
            if ext_map is None:
                ext_map = _load_ext_map()
            mimetype = ext_map.get(e.key)
            if not mimetype:
                skipped.append(
                    (f"ext:{e.key}", "unknown extension (not in shared-mime-info)")
                )
                continue
            mime_desired[mimetype] = e.desktop_id

    plan = DefaultsPlan()
    dirs = _desktop_dirs()
    installed_cache: dict[str, bool] = {}

    def installed(desktop_id: str) -> bool:
        if desktop_id not in installed_cache:
            installed_cache[desktop_id] = any((d / desktop_id).is_file() for d in dirs)
        return installed_cache[desktop_id]

    if mime_desired and not shutil.which("xdg-mime"):
        skipped.append(("mime", "xdg-mime not found"))
    else:
        for mimetype, desired_id in mime_desired.items():
            if not installed(desired_id):
                # A dangling default silently falls back to the cache; skip it.
                skipped.append((mimetype, f"{desired_id} not installed"))
                continue
            current = _xdg_mime_default(mimetype)
            if current != desired_id:
                plan.to_set_mime.append((mimetype, desired_id, current))

    if browser_id is not None:
        if not shutil.which("xdg-settings"):
            skipped.append(("browser", "xdg-settings not found"))
        elif not installed(browser_id):
            skipped.append(("browser", f"{browser_id} not installed"))
        else:
            current = _xdg_settings_browser()
            if current != browser_id:
                plan.browser = (browser_id, current)

    if terminal_id is not None:
        if not installed(terminal_id):
            skipped.append(("terminal", f"{terminal_id} not installed"))
        else:
            current = _terminal_current()
            if current != terminal_id:
                plan.terminal = (terminal_id, current)

    plan.to_set_mime.sort()
    plan.skipped = sorted(skipped)
    return plan


def check() -> int:
    return manifest_check(_load_defaults)
