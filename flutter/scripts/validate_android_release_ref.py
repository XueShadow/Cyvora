#!/usr/bin/env python3
"""Verify an Android release tag points to the protected default branch."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

STABLE_TAG = re.compile(r"^v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$")


class ReleaseRefError(ValueError):
    pass


def _git(repository: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ReleaseRefError(
            f"git {' '.join(arguments)} failed"
            + (f": {detail}" if detail else ".")
        )
    return result.stdout.strip()


def validate_release_ref(
    repository: Path,
    tag: str,
    default_branch: str,
    event_name: str,
    event_ref: str,
) -> str:
    if not STABLE_TAG.fullmatch(tag):
        raise ReleaseRefError("A stable vMAJOR.MINOR.PATCH tag is required.")

    _git(repository, "check-ref-format", f"refs/heads/{default_branch}")

    if event_name == "push":
        expected_ref = f"refs/tags/{tag}"
    elif event_name == "workflow_dispatch":
        expected_ref = f"refs/heads/{default_branch}"
    else:
        raise ReleaseRefError(f"Unsupported release event: {event_name}.")
    if event_ref != expected_ref:
        raise ReleaseRefError(
            f"Release event ref must be {expected_ref!r}, got {event_ref!r}."
        )

    target_commit = _git(
        repository,
        "rev-parse",
        "--verify",
        f"refs/tags/{tag}^{{commit}}",
    )
    protected_branch_commit = _git(
        repository,
        "rev-parse",
        "--verify",
        f"refs/remotes/origin/{default_branch}^{{commit}}",
    )
    ancestry = subprocess.run(
        [
            "git",
            "-C",
            str(repository),
            "merge-base",
            "--is-ancestor",
            target_commit,
            protected_branch_commit,
        ],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if ancestry.returncode == 1:
        raise ReleaseRefError(
            f"Tag {tag} does not point to a commit on "
            f"origin/{default_branch}."
        )
    if ancestry.returncode:
        detail = ancestry.stderr.strip()
        raise ReleaseRefError(
            "Could not verify release commit ancestry"
            + (f": {detail}" if detail else ".")
        )
    return target_commit


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path.cwd())
    parser.add_argument("--tag", required=True)
    parser.add_argument("--default-branch", required=True)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--event-ref", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        target_commit = validate_release_ref(
            args.repository,
            args.tag,
            args.default_branch,
            args.event_name,
            args.event_ref,
        )
    except (OSError, ReleaseRefError) as error:
        print(f"Android release ref validation failed: {error}", file=sys.stderr)
        return 1
    print(target_commit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
