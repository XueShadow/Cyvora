#!/usr/bin/env python3
"""Static release-workflow policy checks; GitHub settings remain external."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


WORKSPACE = Path(__file__).resolve().parents[2]
WORKFLOW = (WORKSPACE / ".github" / "workflows" / "android-release.yml").read_text(
    encoding="utf-8"
)


class AndroidReleaseWorkflowTests(unittest.TestCase):
    def test_pull_requests_do_not_trigger_the_signing_workflow(self) -> None:
        triggers = WORKFLOW.split("\npermissions:", maxsplit=1)[0]
        self.assertNotRegex(triggers, r"(?m)^\s+pull_request(?::|\s*$)")
        self.assertNotIn("pull_request_target", triggers)

    def test_signing_and_publishing_require_distinct_environments(self) -> None:
        self.assertIn("name: android-signing", WORKFLOW)
        self.assertIn("name: android-publish", WORKFLOW)

    def test_write_permission_is_limited_to_release_publishing(self) -> None:
        self.assertEqual(WORKFLOW.count("contents: write"), 1)
        self.assertRegex(
            WORKFLOW,
            r"(?s)publish-release:.*?permissions:\s+contents: write",
        )

    def test_build_uses_the_validated_tag_commit(self) -> None:
        self.assertIn("ref: ${{ needs.validate-release.outputs.target_sha }}", WORKFLOW)
        self.assertIn("--tag \"$RELEASE_TAG\"", WORKFLOW)

    def test_signing_keystore_is_verified_before_building(self) -> None:
        self.assertRegex(
            WORKFLOW,
            r"(?s)Verify signing keystore and alias.*?"
            r"keytool -list.*?"
            r"Build Android App Bundle",
        )


if __name__ == "__main__":
    unittest.main()
