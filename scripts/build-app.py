#!/usr/bin/env python3
"""Build a self-contained app. Python is a build tool, never a runtime dependency."""

import argparse
import hashlib
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def stable_version(value):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise argparse.ArgumentTypeError(
            "version must be MAJOR.MINOR.PATCH without leading zeros, a v prefix, or suffixes"
        )
    return value


def build_number(value):
    if not re.fullmatch(r"[1-9][0-9]*", value):
        raise argparse.ArgumentTypeError("build number must be a positive integer string")
    return value


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sign",
        default="-",
        help="Code signing identity; default is local ad-hoc signing",
    )
    parser.add_argument(
        "--universal",
        action="store_true",
        help="Build for both Apple Silicon and Intel",
    )
    parser.add_argument("--version", type=stable_version, help="Stable MAJOR.MINOR.PATCH")
    parser.add_argument("--build-number", type=build_number, help="Positive build number")
    parser.add_argument(
        "--archive",
        action="store_true",
        help="Create a ZIP; requires --version and --universal",
    )
    options = parser.parse_args(argv)
    if options.archive and (options.version is None or not options.universal):
        parser.error("--archive requires both --version and --universal")
    return options


def stamp_plist(path, version=None, number=None):
    if version is None and number is None:
        return
    with path.open("rb") as source:
        info = plistlib.load(source)
    if version is not None:
        info["CFBundleShortVersionString"] = version
    if number is not None:
        info["CFBundleVersion"] = number
    with path.open("wb") as destination:
        plistlib.dump(info, destination, sort_keys=False)


def archive_app(app, version):
    archive = app.parent / f"Timelapse-v{version}-macos-universal.zip"
    # ditto can update existing archives; start fresh to avoid stale entries.
    archive.unlink(missing_ok=True)
    checksum = archive.with_suffix(".zip.sha256")
    checksum.unlink(missing_ok=True)
    run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive))
    with archive.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    checksum.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    return archive


def main(argv=None):
    options = parse_args(argv)
    build = ["swift", "build", "-c", "release"]
    if options.universal:
        build += ["--arch", "arm64", "--arch", "x86_64"]
    run(*build)
    binary_directory = Path(
        subprocess.check_output(build + ["--show-bin-path"], cwd=ROOT, text=True).strip()
    )
    app = ROOT / "dist" / "Timelapse.app"
    if app.exists():
        shutil.rmtree(app)
    macos = app / "Contents" / "MacOS"
    resources = app / "Contents" / "Resources"
    macos.mkdir(parents=True)
    resources.mkdir()
    binary = macos / "Timelapse"
    shutil.copy2(binary_directory / "Timelapse", binary)
    info = app / "Contents" / "Info.plist"
    shutil.copy2(ROOT / "Resources" / "Info.plist", info)
    stamp_plist(info, options.version, options.build_number)
    if options.universal:
        run("lipo", str(binary), "-verify_arch", "arm64", "x86_64")
    run("codesign", "--force", "--options", "runtime", "--sign", options.sign, str(app))
    run("codesign", "--verify", "--strict", str(app))
    if options.archive:
        print(f"Archived {archive_app(app, options.version)}")
    print(f"\nBuilt {app}\nLaunch with: open dist/Timelapse.app")
    if options.sign == "-":
        print("Local development build only (ad-hoc signed).")
    print(
        "Warning: this app is not notarized. Public distribution requires Developer ID signing and notarization."
    )


if __name__ == "__main__":
    main()
