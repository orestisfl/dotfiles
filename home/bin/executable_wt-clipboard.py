#!/usr/bin/env python3
"""Open the GitHub PR or issue on the clipboard in a `wt` worktree.

Driven from i3-rofi-actions: `--check` is the menu predicate and prints the
label to show, a bare run resolves the checkout and does the work in a new
terminal.
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

PROG = "wt-clipboard"
SRC_ROOT = Path.home() / "src"
MAX_DEPTH = 3
SKIP_DIRS = {"node_modules", "vendor", "target", "build", "__pycache__"}
BRANCH_SLUG_LEN = 40

# The kind is only a hint: GitHub serves both paths for either kind.
REF_RE = re.compile(
    r"(?:https?://)?"
    r"(?:api\.github\.com/repos/|(?:www\.)?github\.com/)"
    r"(?P<owner>[\w.-]+)/(?P<repo>[\w.-]+)/"
    r"(?P<kind>pulls?|issues?)/(?P<number>\d+)",
    re.IGNORECASE,
)
# Conventional "[area] real title" prefixes, dropped so truncation keeps words
# that actually describe the issue.
TAG_PREFIX_RE = re.compile(r"^\s*(?:\[[^\]]*\]|\([^)]*\))\s*")


@dataclass(frozen=True)
class Ref:
    owner: str
    repo: str
    number: int
    is_pr: bool

    @property
    def slug(self) -> str:
        return f"{self.owner}/{self.repo}"

    @property
    def label(self) -> str:
        kind = "PR" if self.is_pr else "issue"
        return f"Open {kind} {self.slug}#{self.number} in worktree"


@dataclass(frozen=True)
class Checkout:
    path: Path
    depth: int
    remote_match: bool
    mtime: float

    @property
    def rank(self) -> tuple[bool, int, float]:
        return (not self.remote_match, self.depth, -self.mtime)


def parse_ref(text: str) -> Ref | None:
    match = REF_RE.search(text or "")
    if match is None:
        return None
    return Ref(
        owner=match["owner"],
        repo=re.sub(r"\.git$", "", match["repo"]),
        number=int(match["number"]),
        is_pr=match["kind"].lower().startswith("pull"),
    )


def read_clipboard() -> str:
    tools = []
    if os.environ.get("WAYLAND_DISPLAY"):
        tools.append(["wl-paste", "--no-newline"])
    tools.append(["xclip", "-selection", "clipboard", "-o"])
    tools.append(["xsel", "--clipboard", "--output"])

    for tool in tools:
        if not shutil.which(tool[0]):
            continue
        try:
            done = subprocess.run(
                tool, capture_output=True, text=True, errors="replace", timeout=2
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if done.returncode == 0 and done.stdout.strip():
            return done.stdout
    return ""


def gh_api(path: str, jq: str) -> str | None:
    """One `gh api` line, or None when gh is missing or the call fails."""
    if not shutil.which("gh"):
        return None
    try:
        done = subprocess.run(
            ["gh", "api", path, "--jq", jq],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if done.returncode != 0:
        print(f"{PROG}: gh api {path} failed, falling back", file=sys.stderr)
        return None
    return done.stdout.strip("\n")


def query_github(ref: Ref) -> tuple[Ref, str]:
    """Correct the PR/issue kind and fetch the title.

    `repos/{owner}/{repo}/issues/{n}` answers for both kinds, and only carries
    a `pull_request` key for PRs.
    """
    jq = '[(if .pull_request then "pr" else "issue" end), (.title // "")] | @tsv'
    out = gh_api(f"repos/{ref.owner}/{ref.repo}/issues/{ref.number}", jq)
    if out is None:
        return ref, ""

    kind, _, title = out.partition("\t")
    return Ref(ref.owner, ref.repo, ref.number, kind == "pr"), title.strip()


def query_pr_head(ref: Ref) -> tuple[str, str] | None:
    """The (owner/repo, branch) a PR is proposing, or None if unknown.

    `.head.repo` is null once the fork is gone, which leaves nothing local to
    match against.
    """
    jq = '[(.head.repo.full_name // ""), (.head.ref // "")] | @tsv'
    out = gh_api(f"repos/{ref.owner}/{ref.repo}/pulls/{ref.number}", jq)
    if not out:
        return None
    slug, _, branch = out.partition("\t")
    return (slug, branch) if slug and branch else None


def find_checkouts(ref: Ref) -> list[Checkout]:
    """Every `<repo>/.git` under ~/src, best first.

    Scans level by level to MAX_DEPTH and never descends into a checkout, so a
    shallow match outranks a deeper one unless only the deeper one has a remote
    pointing at owner/repo.
    """
    found: list[Checkout] = []
    level = [SRC_ROOT]

    for depth in range(1, MAX_DEPTH + 1):
        children: list[Path] = []
        for parent in level:
            try:
                entries = sorted(os.scandir(parent), key=lambda e: e.name)
            except OSError:
                continue
            for entry in entries:
                if entry.name.startswith(".") or entry.name in SKIP_DIRS:
                    continue
                if not entry.is_dir(follow_symlinks=False):
                    continue
                path = Path(entry.path)
                if (path / ".git").exists():
                    if path.name == ref.repo:
                        found.append(_describe_checkout(path, depth, ref))
                    continue
                children.append(path)
        level = children

    return sorted(found, key=lambda c: c.rank)


def _describe_checkout(path: Path, depth: int, ref: Ref) -> Checkout:
    git_dir = path / ".git"
    remote_match = False
    try:
        config = (git_dir / "config").read_text(errors="ignore")
        remote_match = ref.slug.lower() in config.lower()
    except OSError:
        pass
    try:
        mtime = git_dir.stat().st_mtime
    except OSError:
        mtime = 0.0
    return Checkout(path, depth, remote_match, mtime)


def pick_checkout(candidates: list[Checkout], prompt: bool) -> Path | None:
    """None means the user cancelled the picker."""
    best = candidates[0]
    tied = [c for c in candidates if c.rank[:2] == best.rank[:2]]
    if len(tied) == 1 or not prompt or not shutil.which("rofi"):
        return best.path

    home = str(Path.home())
    menu = "\n".join(str(c.path).replace(home, "~", 1) for c in tied)
    done = subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-format",
            "i",
            "-l",
            str(len(tied)),
            "-p",
            "Checkout",
        ],
        input=menu,
        capture_output=True,
        text=True,
    )
    if done.returncode != 0 or not done.stdout.strip():
        return None
    return tied[int(done.stdout.strip())].path


def slugify(title: str, max_len: int = BRANCH_SLUG_LEN) -> str:
    while (stripped := TAG_PREFIX_RE.sub("", title)) and stripped != title:
        title = stripped

    slug = ""
    for word in re.findall(r"[a-z0-9]+", title.lower()):
        candidate = f"{slug}-{word}" if slug else word
        if len(candidate) > max_len:
            break
        slug = candidate
    return slug


def _ai_branch_name(ref: Ref, title: str) -> str:
    raise NotImplementedError("--name-strategy=ai is not wired up yet")


def issue_branch(ref: Ref, title: str, strategy: str) -> str:
    if strategy == "ai":
        return _ai_branch_name(ref, title)
    slug = slugify(title)
    return f"issue-{ref.number}-{slug}" if slug else f"issue-{ref.number}"


def git(repo: Path, *args: str) -> str | None:
    try:
        done = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return done.stdout if done.returncode == 0 else None


def existing_issue_branch(repo: Path, number: int) -> str | None:
    """A branch this script already made for the issue.

    Matched on the number alone so reopening an issue returns to its worktree
    even after the title, and therefore the slug, has changed.
    """
    out = git(
        repo,
        "for-each-ref",
        "--format=%(refname:short)",
        f"refs/heads/issue-{number}",
        f"refs/heads/issue-{number}-*",
    )
    names = (out or "").split()
    return names[0] if names else None


def remote_slug(url: str) -> str:
    """owner/repo out of any remote URL spelling."""
    parts = re.sub(r"\.git$", "", url.strip()).replace(":", "/").split("/")
    return "/".join(parts[-2:]).lower()


def existing_pr_branch(repo: Path, head_slug: str, head_branch: str) -> str | None:
    """A local branch already tracking the branch the PR proposes.

    `wt switch pr:{n}` only reuses a branch whose config points at
    refs/pull/{n}/head, so a branch tracking the head branch on its own remote
    — the usual shape when the PR is ours — looks unrelated and wt creates a
    second, fork-prefixed branch for the same commits.
    """
    if not head_branch:
        return None
    config = git(repo, "config", "--get-regexp", r"^remote\..*\.url$") or ""
    wanted = set()
    for line in config.splitlines():
        key, _, url = line.partition(" ")
        if remote_slug(url) == head_slug.lower():
            remote = key[len("remote.") : -len(".url")]
            wanted.add(f"refs/remotes/{remote}/{head_branch}")
    if not wanted:
        return None

    fmt = "--format=%(refname:short)\t%(upstream)\t%(worktreepath)"
    matches = []
    for line in (git(repo, "for-each-ref", fmt, "refs/heads/") or "").splitlines():
        name, upstream, worktree = line.split("\t")
        if upstream in wanted:
            # Sorts fork-prefixed leftovers of earlier `pr:` switches last.
            matches.append((not worktree, name != head_branch, name))
    return min(matches)[2] if matches else None


def wt_argv(repo: Path, ref: Ref, title: str, strategy: str) -> list[str]:
    if ref.is_pr:
        head_slug, head_branch = query_pr_head(ref) or ("", "")
        branch = existing_pr_branch(repo, head_slug, head_branch)
        # wt resolves a same-repo PR to its head branch and fetches it on the
        # way, so leave `pr:` alone unless we found something it would miss.
        same_repo = head_slug.lower() == ref.slug.lower()
        if branch and not (same_repo and branch == head_branch):
            return ["switch", branch]
        return ["switch", f"pr:{ref.number}"]
    existing = existing_issue_branch(repo, ref.number)
    if existing:
        return ["switch", existing]
    return ["switch", "--create", issue_branch(ref, title, strategy)]


def launch(repo: Path, ref: Ref, wt_args: list[str], dry_run: bool) -> int:
    # An interactive shell so wt resolves to the zsh function, which is what
    # applies wt's cd directive. Deliberately not `wt -x zsh`, which reports the
    # shell's exit code as its own and so cannot tell a failed switch from a
    # failed command.
    #
    # The window is named through TERM_TITLE because the terminal's own --title
    # pins the title and so blocks the OSC handshake ghostty-wm.zsh needs to
    # mark the window for term.sh.
    script = "; ".join(
        [
            f"export TERM_TITLE={shlex.quote(f'wt {ref.slug}#{ref.number}')}",
            shlex.join(["wt", "-C", str(repo), *wt_args]),
            "exec zsh -i",
        ]
    )

    argv = [
        "xdg-terminal-exec",
        f"--dir={repo}",
        "--",
        "zsh",
        "-i",
        "-c",
        script,
    ]
    if dry_run:
        print(shlex.join(argv))
        return 0
    return spawn_detached(argv, f"wt worktree for {ref.slug}#{ref.number}")


def spawn_detached(argv: list[str], description: str) -> int:
    """Outlive the rofi action that started us.

    Everything is redirected because the caller reads our output through a
    command substitution: a child holding that pipe open would block the menu
    until the terminal closed.
    """
    quiet = {
        "stdin": subprocess.DEVNULL,
        "stdout": subprocess.DEVNULL,
        "stderr": subprocess.DEVNULL,
    }
    if shutil.which("systemd-run"):
        unit = ["systemd-run", "--user", "--collect", f"--description={description}"]
        if subprocess.call([*unit, *argv], **quiet) == 0:
            return 0
    subprocess.Popen(argv, start_new_session=True, **quiet)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog=PROG, description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="print the menu label for the clipboard URL, or exit 1",
    )
    parser.add_argument("--url", help="use this URL instead of the clipboard")
    parser.add_argument(
        "--name-strategy",
        choices=("slug", "ai"),
        default="slug",
        help="how to name the branch for an issue (default: slug)",
    )
    parser.add_argument(
        "--first",
        action="store_true",
        help="take the best guess instead of asking when several checkouts match",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print the terminal command and exit"
    )
    args = parser.parse_args()

    ref = parse_ref(args.url or read_clipboard())

    if args.check:
        if ref is None or not shutil.which("wt"):
            return 1
        print(ref.label)
        return 0

    if ref is None:
        sys.exit(f"{PROG}: no GitHub PR or issue URL on the clipboard")

    ref, title = query_github(ref)

    candidates = find_checkouts(ref)
    if not candidates:
        sys.exit(f"{PROG}: no {ref.repo} checkout under {SRC_ROOT} (depth {MAX_DEPTH})")
    repo = pick_checkout(candidates, prompt=not args.first)
    if repo is None:
        return 0

    try:
        wt_args = wt_argv(repo, ref, title, args.name_strategy)
    except NotImplementedError as exc:
        sys.exit(f"{PROG}: {exc}")

    return launch(repo, ref, wt_args, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
