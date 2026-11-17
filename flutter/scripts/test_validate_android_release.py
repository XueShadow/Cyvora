#!/usr/bin/env python3
"""Tests for Android release tag and artifact version agreement."""

from __future__ import annotations

import unittest

from validate_android_release import (
    ValidationError,
    validate_release_tag_version,
)


class ValidateAndroidReleaseTagVersionTests(unittest.TestCase):
    def test_accepts_matching_release_tag(self) -> None:
        validate_release_tag_version("v1.2.3", "1.2.3")

    def test_accepts_missing_tag_for_non_release_validation(self) -> None:
        validate_release_tag_version(None, "1.2.3")

    def test_rejects_artifact_version_that_does_not_match_tag(self) -> None:
        with self.assertRaisesRegex(ValidationError, "must match"):
            validate_release_tag_version("v1.2.4", "1.2.3")


if __name__ == "__main__":
    unittest.main()
