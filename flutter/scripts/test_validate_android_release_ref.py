#!/usr/bin/env python3
"""Tests for Android release tag and protected-branch validation."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from validate_android_release_ref import ReleaseRefError, validate_release_ref


class ValidateAndroidReleaseRefTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repository = Path(self.temporary_directory.name)
        self._git("init", "--initial-branch=main")
        self._git("config", "user.name", "Cyvora test")
        self._git("config", "user.email", "cyvora-test@example.invalid")
        (self.repository / "tracked.txt").write_text("approved\n", encoding="utf-8")
        self._git("add", "tracked.txt")
        self._git("commit", "-m", "approved release commit")
        self._git("update-ref", "refs/remotes/origin/main", "HEAD")
        self._git("tag", "v1.2.3")
        self.approved_commit = self._git("rev-parse", "HEAD")

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def _git(self, *arguments: str) -> str:
        result = subprocess.run(
            ["git", "-C", str(self.repository), *arguments],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode:
            self.fail(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()

    def _validate(
        self,
        tag: str = "v1.2.3",
        event_name: str = "push",
        event_ref: str = "refs/tags/v1.2.3",
    ) -> str:
        return validate_release_ref(
            self.repository,
            tag,
            "main",
            event_name,
            event_ref,
        )

    def test_accepts_stable_tag_on_protected_branch(self) -> None:
        self.assertEqual(self._validate(), self.approved_commit)

    def test_accepts_existing_tag_from_default_branch_dispatch(self) -> None:
        commit = self._validate(
            event_name="workflow_dispatch",
            event_ref="refs/heads/main",
        )
        self.assertEqual(commit, self.approved_commit)

    def test_rejects_non_semver_tag(self) -> None:
        with self.assertRaisesRegex(ReleaseRefError, "stable"):
            self._validate("v1.2.3-test")

    def test_rejects_dispatch_from_non_default_branch(self) -> None:
        with self.assertRaisesRegex(ReleaseRefError, "event ref"):
            self._validate(
                event_name="workflow_dispatch",
                event_ref="refs/heads/untrusted",
            )

    def test_rejects_tag_ref_that_does_not_match_tag_name(self) -> None:
        with self.assertRaisesRegex(ReleaseRefError, "event ref"):
            self._validate(event_ref="refs/tags/v9.9.9")

    def test_rejects_pull_request_event(self) -> None:
        with self.assertRaisesRegex(ReleaseRefError, "Unsupported release event"):
            self._validate(
                event_name="pull_request",
                event_ref="refs/pull/42/merge",
            )

    def test_rejects_tag_commit_not_on_protected_branch(self) -> None:
        self._git("checkout", "-b", "untrusted")
        (self.repository / "tracked.txt").write_text("unreviewed\n", encoding="utf-8")
        self._git("commit", "-am", "unreviewed release commit")
        self._git("tag", "v1.2.4")
        with self.assertRaisesRegex(ReleaseRefError, "does not point"):
            self._validate(
                "v1.2.4",
                event_ref="refs/tags/v1.2.4",
            )

    def test_rejects_missing_tag(self) -> None:
        with self.assertRaisesRegex(ReleaseRefError, "rev-parse"):
            self._validate("v1.2.4", event_ref="refs/tags/v1.2.4")


if __name__ == "__main__":
    unittest.main()
