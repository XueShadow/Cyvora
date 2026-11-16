#!/usr/bin/env python3
"""Validate, name, and checksum Cyvora Android release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

APPLICATION_ID = "com.example.cyvora_mobile"
MINIMUM_API = 24
MINIMUM_TARGET_API = 35
REQUIRED_ABIS = {"arm64-v8a", "armeabi-v7a", "x86_64"}
REQUIRED_PERMISSIONS = {
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.POST_NOTIFICATIONS",
}
PRODUCTION_CERT_SHA256 = (
    "d732eaa269a8707b2447c73aee5a14885d030d59b9dc7382302321c750ad3afa"
)


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def run_tool(command: list[str]) -> str:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError as error:
        fail(f"Could not run {command[0]}: {error}")
    output = f"{result.stdout}{result.stderr}"
    if result.returncode:
        fail(f"{Path(command[0]).name} failed:\n{output.strip()}")
    return output


def find_java() -> Path:
    java_home = os.environ.get("JAVA_HOME")
    candidates = []
    if java_home:
        suffix = ".exe" if os.name == "nt" else ""
        candidates.append(Path(java_home) / "bin" / f"java{suffix}")
    java = shutil.which("java")
    if java:
        candidates.append(Path(java))
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    fail("Java was not found. Configure JAVA_HOME or add java to PATH.")


def find_android_tools(sdk_root: Path) -> tuple[Path, Path]:
    build_tools = sdk_root / "build-tools"
    if not build_tools.is_dir():
        fail(f"Android build-tools were not found under {sdk_root}.")

    def version_key(path: Path) -> tuple[int, ...]:
        return tuple(int(part) for part in re.findall(r"\d+", path.name))

    versions = sorted(
        (path for path in build_tools.iterdir() if path.is_dir()),
        key=version_key,
        reverse=True,
    )
    suffixes = (".exe", "") if os.name == "nt" else ("",)
    for version in versions:
        aapt = next(
            (version / f"aapt{suffix}" for suffix in suffixes if (version / f"aapt{suffix}").is_file()),
            None,
        )
        apksigner = version / "lib" / "apksigner.jar"
        if aapt and apksigner.is_file():
            return aapt, apksigner
    fail(f"Could not find aapt and apksigner.jar under {build_tools}.")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_zip(path: Path, required_entries: set[str]) -> set[str]:
    if not path.is_file():
        fail(f"Required artifact does not exist: {path}")
    if path.stat().st_size == 0:
        fail(f"Artifact is empty: {path}")
    try:
        with zipfile.ZipFile(path) as archive:
            corrupted_entry = archive.testzip()
            if corrupted_entry:
                fail(f"{path.name} contains a corrupted entry: {corrupted_entry}")
            names = set(archive.namelist())
    except zipfile.BadZipFile as error:
        fail(f"{path.name} is not a valid ZIP-based Android artifact: {error}")
    missing = required_entries - names
    if missing:
        fail(f"{path.name} is missing required entries: {', '.join(sorted(missing))}")
    return names


def read_apk_metadata(aapt: Path, apk: Path) -> tuple[dict[str, str], set[str], str]:
    badging = run_tool([str(aapt), "dump", "badging", str(apk)])
    package_line = re.search(r"^package: (.+)$", badging, re.MULTILINE)
    if not package_line:
        fail("aapt did not report APK package metadata.")
    fields = dict(re.findall(r"([A-Za-z]+)='([^']*)'", package_line.group(1)))
    min_sdk = re.search(r"^sdkVersion:'(\d+)'$", badging, re.MULTILINE)
    target_sdk = re.search(r"^targetSdkVersion:'(\d+)'$", badging, re.MULTILINE)
    if not min_sdk or not target_sdk:
        fail("aapt did not report APK minimum and target SDK versions.")
    fields["minSdkVersion"] = min_sdk.group(1)
    fields["targetSdkVersion"] = target_sdk.group(1)
    native_line = re.search(r"^native-code:\s*(.*)$", badging, re.MULTILINE)
    abis = set(re.findall(r"'([^']+)'", native_line.group(1))) if native_line else set()
    return fields, abis, badging


def verify_apk_signature(
    java: Path,
    apksigner_jar: Path,
    apk: Path,
) -> str:
    output = run_tool(
        [
            str(java),
            "-jar",
            str(apksigner_jar),
            "verify",
            "--verbose",
            "--print-certs",
            str(apk),
        ]
    )
    fingerprint = re.search(
        r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)",
        output,
    )
    if not fingerprint:
        fail(f"Could not read the signer fingerprint for {apk.name}.")
    return fingerprint.group(1).lower()


def verify_aab_signature(
    jarsigner: Path,
    keytool: Path,
    aab: Path,
) -> str:
    output = run_tool([str(jarsigner), "-verify", str(aab)])
    if "jar verified." not in output.lower():
        fail("AAB signature verification did not report a verified archive.")
    certificate = run_tool([str(keytool), "-printcert", "-jarfile", str(aab)])
    fingerprint = re.search(r"SHA256:\s*([0-9a-fA-F:]+)", certificate)
    if not fingerprint:
        fail("Could not read the AAB signer fingerprint.")
    return fingerprint.group(1).replace(":", "").lower()


def read_pubspec_version(pubspec: Path) -> tuple[str, int]:
    text = pubspec.read_text(encoding="utf-8")
    version = re.search(
        r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
        text,
        re.MULTILINE,
    )
    if not version:
        fail("pubspec.yaml version must use name+build-number format.")
    return version.group(1), int(version.group(2))


def validate(args: argparse.Namespace) -> None:
    sdk_root = args.sdk
    if not sdk_root:
        sdk_root = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not sdk_root:
        fail("Set ANDROID_SDK_ROOT or pass --sdk to locate Android build-tools.")

    sdk_root = Path(sdk_root)
    aapt, apksigner_jar = find_android_tools(sdk_root)
    java = find_java()
    java_bin = java.parent
    suffix = ".exe" if os.name == "nt" else ""
    jarsigner_candidate = java_bin / f"jarsigner{suffix}"
    keytool_candidate = java_bin / f"keytool{suffix}"
    jarsigner = jarsigner_candidate if jarsigner_candidate.is_file() else shutil.which("jarsigner")
    keytool = keytool_candidate if keytool_candidate.is_file() else shutil.which("keytool")
    if not jarsigner or not keytool:
        fail("jarsigner and keytool must be available through JAVA_HOME or PATH.")
    jarsigner = Path(jarsigner)
    keytool = Path(keytool)

    apk_entries = check_zip(args.apk, {"AndroidManifest.xml", "classes.dex"})
    aab_entries = check_zip(
        args.aab,
        {"BundleConfig.pb", "base/manifest/AndroidManifest.xml"},
    )
    del aab_entries

    metadata, apis, badging = read_apk_metadata(aapt, args.apk)
    if metadata.get("name") != APPLICATION_ID:
        fail(
            f"APK package ID is {metadata.get('name')!r}; "
            f"expected {APPLICATION_ID!r}."
        )
    if int(metadata["minSdkVersion"]) != MINIMUM_API:
        fail(
            f"APK minSdk is {metadata['minSdkVersion']}; expected {MINIMUM_API}."
        )
    if int(metadata["targetSdkVersion"]) < MINIMUM_TARGET_API:
        fail(
            f"APK targetSdk is {metadata['targetSdkVersion']}; "
            f"expected at least {MINIMUM_TARGET_API}."
        )
    missing_abis = REQUIRED_ABIS - apis
    if missing_abis:
        fail(f"APK is missing ABIs: {', '.join(sorted(missing_abis))}.")
    packaged_abis = {
        match.group(1)
        for name in apk_entries
        if (match := re.match(r"lib/([^/]+)/", name))
    }
    if not REQUIRED_ABIS <= packaged_abis:
        fail(
            "APK native library entries are missing ABIs: "
            f"{', '.join(sorted(REQUIRED_ABIS - packaged_abis))}."
        )

    missing_permissions = {
        permission
        for permission in REQUIRED_PERMISSIONS
        if f"uses-permission: name='{permission}'" not in badging
    }
    if missing_permissions:
        fail(
            "APK is missing required permissions: "
            f"{', '.join(sorted(missing_permissions))}."
        )
    manifest_tree = run_tool([str(aapt), "dump", "xmltree", str(args.apk), "AndroidManifest.xml"])
    required_manifest_values = (
        f"{APPLICATION_ID}.MessageNotificationListenerService",
        "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
    )
    if any(value not in manifest_tree for value in required_manifest_values):
        fail("APK manifest is missing the notification listener component or binding permission.")

    version_name, version_code = read_pubspec_version(args.pubspec)
    if metadata.get("versionName") != version_name:
        fail(
            f"APK versionName is {metadata.get('versionName')!r}; "
            f"pubspec.yaml declares {version_name!r}."
        )
    if metadata.get("versionCode") != str(version_code):
        fail(
            f"APK versionCode is {metadata.get('versionCode')!r}; "
            f"pubspec.yaml declares {version_code}."
        )
    if args.tag and args.tag != f"v{version_name}":
        fail(f"Release tag {args.tag!r} must match pubspec version v{version_name}.")

    apk_certificate = verify_apk_signature(java, apksigner_jar, args.apk)
    if apk_certificate != PRODUCTION_CERT_SHA256:
        fail(
            "APK signer does not match the established production certificate "
            f"(expected SHA-256 {PRODUCTION_CERT_SHA256})."
        )
    aab_certificate = verify_aab_signature(jarsigner, keytool, args.aab)
    if aab_certificate != PRODUCTION_CERT_SHA256:
        fail(
            "AAB signer does not match the established production certificate "
            f"(expected SHA-256 {PRODUCTION_CERT_SHA256})."
        )
    if apk_certificate != aab_certificate:
        fail("APK and AAB were signed with different certificates.")

    if args.previous_apk:
        check_zip(args.previous_apk, {"AndroidManifest.xml"})
        previous, _, _ = read_apk_metadata(aapt, args.previous_apk)
        if previous.get("name") != APPLICATION_ID:
            fail("The previous production APK has a different package ID.")
        previous_certificate = verify_apk_signature(
            java,
            apksigner_jar,
            args.previous_apk,
        )
        if previous_certificate != PRODUCTION_CERT_SHA256:
            fail("The previous production APK uses a different signing certificate.")
        if int(metadata["versionCode"]) <= int(previous["versionCode"]):
            fail(
                f"versionCode {metadata['versionCode']} must be greater than "
                f"the previous release's {previous['versionCode']}."
            )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    staged_apk = args.output_dir / "cyvora-universal-release.apk"
    staged_aab = args.output_dir / "cyvora-release.aab"
    shutil.copy2(args.apk, staged_apk)
    shutil.copy2(args.aab, staged_aab)
    checksum_file = args.output_dir / "SHA256SUMS.txt"
    checksum_file.write_text(
        f"{sha256(staged_apk)}  {staged_apk.name}\n"
        f"{sha256(staged_aab)}  {staged_aab.name}\n",
        encoding="utf-8",
    )
    (args.output_dir / "APK_CERT_SHA256.txt").write_text(
        f"{apk_certificate}\n",
        encoding="utf-8",
    )

    print(f"Package: {APPLICATION_ID}")
    print(
        f"Version: {version_name} (versionCode {version_code}); "
        f"minSdk {metadata['minSdkVersion']}, targetSdk {metadata['targetSdkVersion']}"
    )
    print(f"Native ABIs: {', '.join(sorted(apis))}")
    print(f"Production signer SHA-256: {apk_certificate}")
    print(f"Validated release files staged in: {args.output_dir}")


def parse_args() -> argparse.Namespace:
    project_dir = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--aab", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--tag")
    parser.add_argument("--previous-apk", type=Path)
    parser.add_argument("--pubspec", type=Path, default=project_dir / "pubspec.yaml")
    parser.add_argument("--sdk", type=Path)
    return parser.parse_args()


def main() -> int:
    try:
        validate(parse_args())
    except (OSError, ValidationError, zipfile.BadZipFile) as error:
        print(f"Android release validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
