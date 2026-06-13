#!/usr/bin/env python3
"""Declarative reconciler for Arch dotfiles — entry point and CLI.

This file is the launcher invoked by absolute path (the chezmoi
`run_onchange_after_40-sync` hook and the systemd-run self re-dispatch in
`common._dispatch_detached`). Running it as a script puts its own directory
(`sync/`) on `sys.path[0]`, so the sibling modules import as top-level names
with no packaging or PYTHONPATH:

    common    shared infrastructure + plan/apply/gui execution engine
    packages  paru install/remove/reason-flip
    etc       root-owned files staged under ~/.local/share/root-staging
    units     systemctl enable/disable (system + --user)
    defaults  XDG default applications

Each domain module exposes `compute_*_plan()` and `check()`; this file binds
them into a `Domain` registry that drives both the argparse CLI and the
top-level combined orchestrator.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from typing import Callable

import defaults
import etc
import packages
import units
from common import CombinedPlan, ReconcilePlan, run_apply, run_gui, run_plan

_Verb = Callable[[argparse.Namespace], int]


@dataclass(frozen=True)
class Domain:
    name: str
    help: str
    compute: Callable[[], ReconcilePlan]
    check: Callable[[], int]
    check_help: str
    plan_help: str
    apply_help: str


# Order matters: install packages first (so e.g. ufw exists), then drop
# root-owned files (so unit files are in /etc/systemd/system), then
# enable/disable units. Defaults come last so the apps they point at
# (firefox, mpv, ...) are already installed and their .desktop present.
DOMAINS: tuple[Domain, ...] = (
    Domain(
        name="packages",
        help="declarative package management",
        compute=packages.compute_packages_plan,
        check=packages.check,
        check_help="validate packages manifest syntax",
        plan_help="print the effective package plan",
        apply_help="run the plan inline (inherits tty for paru prompts)",
    ),
    Domain(
        name="etc",
        help="root-owned files staged under root-staging/",
        compute=etc.compute_etc_plan,
        check=etc.check,
        check_help="report staging dir contents (no manifest to validate)",
        plan_help="print files that differ between staging and /",
        apply_help="copy staged files into / via pkexec",
    ),
    Domain(
        name="units",
        help="declarative systemd unit management",
        compute=units.compute_units_plan,
        check=units.check,
        check_help="validate units manifest syntax",
        plan_help="print the effective unit plan",
        apply_help="enable/disable units inline (polkit prompt via agent)",
    ),
    Domain(
        name="defaults",
        help="declarative XDG default applications",
        compute=defaults.compute_defaults_plan,
        check=defaults.check,
        check_help="validate defaults manifest syntax",
        plan_help="print the effective defaults plan",
        apply_help="set mime/scheme/terminal/browser defaults inline ($HOME only)",
    ),
)

DOMAIN_NAMES = tuple(d.name for d in DOMAINS)


def compute_all() -> CombinedPlan:
    return CombinedPlan(parts=[(d.name, d.compute()) for d in DOMAINS])


def _all_check() -> int:
    rc = 0
    for d in DOMAINS:
        rc |= d.check()
    return rc


def _domain_verbs(domain: Domain) -> dict[str, _Verb]:
    return {
        "check": lambda _a: domain.check(),
        "plan": lambda _a: run_plan(domain.name, domain.compute()),
        "apply": lambda _a: run_apply(domain.name, domain.compute()),
        "gui": lambda _a: run_gui(domain.name, domain.compute()),
    }


_ALL_VERBS: dict[str, _Verb] = {
    "check": lambda _a: _all_check(),
    "plan": lambda _a: run_plan("all", compute_all()),
    "apply": lambda _a: run_apply("all", compute_all()),
    "gui": lambda _a: run_gui("all", compute_all()),
}


DESCRIPTION = (
    "Declarative reconciler for Arch dotfiles. Four subcomponents run in "
    "dependency order on `sync gui` / `sync apply`: packages (paru), etc "
    "(root-owned files staged under ~/.local/share/root-staging), units "
    "(systemctl, system + --user), defaults (XDG default applications)."
)

EPILOG = """\
Top-level (run all four in dependency order: packages → etc → units → defaults):

  sync check        validate manifests + report staging state
  sync plan         print combined plan for this host
  sync apply        execute inline (polkit / pkexec / paru prompts as needed)
  sync gui          single yad review, then xdg-terminal-exec the chain
  sync              alias for `sync gui` (chezmoi run_onchange entry point)

Per-domain subcommands take the same {check, plan, apply, gui} verbs:

  sync packages …   pacman/paru install/remove/reason-flip (packages.txt.tmpl)
  sync etc …        install root-owned files from ~/.local/share/root-staging
  sync units …      systemctl enable/disable, system + --user (units.txt.tmpl)
  sync defaults …   XDG default apps: mime/scheme/terminal/browser (defaults.txt.tmpl)

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

Defaults manifest syntax (one `selector = app.desktop` per line; last wins):

  text/html       = app.desktop   MIME type (files of that type)
  ext:.md         = app.desktop   extension → MIME via shared-mime-info
  scheme:slack    = app.desktop   URL scheme → x-scheme-handler/slack
  terminal        = app.desktop   default terminal (xdg-terminals.list)
  browser         = app.desktop   xdg-settings default-web-browser bundle
"""


def _add_verbs(
    sub: argparse._SubParsersAction,
    verbs: dict[str, _Verb],
    *,
    check_help: str,
    plan_help: str,
    apply_help: str,
) -> None:
    pp = sub.add_parser("check", help=check_help)
    pp.set_defaults(func=verbs["check"])
    pp = sub.add_parser("plan", help=plan_help)
    pp.set_defaults(func=verbs["plan"])
    pp = sub.add_parser("apply", help=apply_help)
    pp.set_defaults(func=verbs["apply"])
    pp = sub.add_parser("gui", help="confirm via yad, dispatch into xdg-terminal-exec")
    pp.set_defaults(func=verbs["gui"])


def main() -> int:
    p = argparse.ArgumentParser(
        prog="sync",
        description=DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    top = p.add_subparsers(
        dest="top",
        metavar="{" + ",".join(("check", "plan", "apply", "gui", *DOMAIN_NAMES)) + "}",
    )

    # Top-level verbs run all four subcomponents in order.
    _add_verbs(
        top,
        _ALL_VERBS,
        check_help="validate every subcomponent",
        plan_help="print the combined plan for all subcomponents",
        apply_help="run all subcomponents inline (sequential, halts on first failure)",
    )

    # Per-domain subparsers, all sharing the {check,plan,apply,gui} verbs.
    for d in DOMAINS:
        dp = top.add_parser(d.name, help=d.help)
        _add_verbs(
            dp.add_subparsers(dest="cmd", metavar="{check,plan,apply,gui}"),
            _domain_verbs(d),
            check_help=d.check_help,
            plan_help=d.plan_help,
            apply_help=d.apply_help,
        )

    args = p.parse_args()
    # Defaults:
    #   sync                              → sync gui  (chezmoi hook entry point)
    #   sync <packages|etc|units|defaults> → that domain's plan
    if not args.top:
        args = p.parse_args(["gui"])
    elif args.top in DOMAIN_NAMES and not getattr(args, "cmd", None):
        args = p.parse_args([args.top, "plan"])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main() or 0)
