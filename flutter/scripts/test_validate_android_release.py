#!/usr/bin/env python3
"""Tests for Android release tag and artifact version agreement."""

from __future__ import annotations

import unittest

from validate_android_release import (
    ValidationError,
    validate_permission_inventory,
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


class ValidateAndroidPermissionInventoryTests(unittest.TestCase):
    def test_accepts_minimal_permission_set(self) -> None:
        requested = validate_permission_inventory(
            "uses-permission: name='android.permission.INTERNET'\n"
            "uses-permission: name='com.example.INTERNAL_PERMISSION'"
        )
        self.assertIn("android.permission.INTERNET", requested)

    def test_rejects_unneeded_notification_permission(self) -> None:
        with self.assertRaisesRegex(ValidationError, "POST_NOTIFICATIONS"):
            validate_permission_inventory(
                "uses-permission: name='android.permission.INTERNET'\n"
                "uses-permission: name='android.permission.POST_NOTIFICATIONS'"
            )

    def test_rejects_sms_permissions(self) -> None:
        with self.assertRaisesRegex(ValidationError, "READ_SMS"):
            validate_permission_inventory(
                "uses-permission: name='android.permission.INTERNET'\n"
                "uses-permission-sdk-23: name='android.permission.READ_SMS'"
            )

    def test_requires_internet(self) -> None:
        with self.assertRaisesRegex(ValidationError, "missing required"):
            validate_permission_inventory(
                "uses-permission: name='android.permission.ACCESS_NETWORK_STATE'"
            )


if __name__ == "__main__":
    unittest.main()
