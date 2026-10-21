import contextlib
import hashlib
import importlib.util
import io
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    "build_app", Path(__file__).resolve().parents[1] / "build-app.py"
)
build_app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build_app)


class ArgumentTests(unittest.TestCase):
    def test_valid_versions_and_build_numbers(self):
        for version in ("0.0.0", "1.2.3", "123.456.789"):
            self.assertEqual(build_app.stable_version(version), version)
        for number in ("1", "42", "12345678901234567890"):
            self.assertEqual(build_app.build_number(number), number)

    def test_invalid_arguments_never_build(self):
        invalid = [
            ["--version", value]
            for value in (
                "v1.2.3",
                "01.2.3",
                "1.02.3",
                "1.2.03",
                "1.2",
                "1.2.3.4",
                "1.2.3-rc.1",
                "1.2.3+build",
                " 1.2.3",
                "1.2.3\n",
                "１.2.3",
                "",
            )
        ]
        invalid += [
            ["--build-number", value]
            for value in ("0", "-1", "01", "+1", "1.0", " 1", "1\n", "１", "")
        ]
        invalid += [
            ["--archive"],
            ["--archive", "--version", "1.2.3"],
            ["--archive", "--universal"],
        ]
        for arguments in invalid:
            with self.subTest(arguments=arguments):
                with mock.patch.object(build_app, "run") as run:
                    with mock.patch.object(build_app.subprocess, "check_output") as output:
                        with contextlib.redirect_stderr(io.StringIO()):
                            with self.assertRaises(SystemExit) as error:
                                build_app.main(arguments)
                        self.assertEqual(error.exception.code, 2)
                        run.assert_not_called()
                        output.assert_not_called()


class PackagingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "Resources" / "Info.plist"
        self.source.parent.mkdir()
        self.original = plistlib.dumps(
            {
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "7",
                "CFBundleIdentifier": "dev.example.timelapse",
                "Other": {"Enabled": True},
            }
        )
        self.source.write_bytes(self.original)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "Timelapse").write_bytes(b"fake executable")
        self.app = self.root / "dist" / "Timelapse.app"
        self.info = self.app / "Contents" / "Info.plist"
        self.commands = []
        self.signed_info = None
        self.fail_command = None
        self.stdout = io.StringIO()
        for patcher in (
            mock.patch.object(build_app, "ROOT", self.root),
            mock.patch.object(build_app, "run", side_effect=self.fake_run),
            mock.patch.object(build_app.subprocess, "check_output", return_value=str(self.bin)),
            contextlib.redirect_stdout(self.stdout),
        ):
            patcher.__enter__()
            self.addCleanup(patcher.__exit__, None, None, None)

    def fake_run(self, *command):
        self.commands.append(command)
        if command[0] == self.fail_command:
            raise subprocess.CalledProcessError(1, command)
        if command[:2] == ("codesign", "--force"):
            self.signed_info = self.info.read_bytes()
        if command[0] == "ditto":
            self.assertEqual(command[1:5], ("-c", "-k", "--sequesterRsrc", "--keepParent"))
            self.assertEqual(self.info.read_bytes(), self.signed_info)
            app = Path(command[-2])
            with zipfile.ZipFile(command[-1], "w") as archive:
                for path in app.rglob("*"):
                    archive.write(path, path.relative_to(app.parent))

    def test_defaults_preserve_plist_and_adhoc_sign(self):
        build_app.main([])
        self.assertEqual(self.info.read_bytes(), self.original)
        self.assertEqual(self.source.read_bytes(), self.original)
        self.assertEqual(self.commands[0], ("swift", "build", "-c", "release"))
        self.assertIn("-", self.commands[1])
        self.assertEqual([cmd[0] for cmd in self.commands], ["swift", "codesign", "codesign"])
        self.assertIn("not notarized", self.stdout.getvalue())

    def test_independent_plist_overrides(self):
        for args, version, number in (
            (["--version", "2.3.4"], "2.3.4", "7"),
            (["--build-number", "42"], "0.1.0", "42"),
        ):
            with self.subTest(args=args):
                build_app.main(args)
                info = plistlib.loads(self.info.read_bytes())
                self.assertEqual(info["CFBundleShortVersionString"], version)
                self.assertEqual(info["CFBundleVersion"], number)
                self.assertEqual(info["Other"], {"Enabled": True})
                self.assertEqual(self.source.read_bytes(), self.original)

    def test_archive_stamped_signed_app_and_checksum(self):
        build_app.main(
            [
                "--archive",
                "--universal",
                "--version",
                "2.3.4",
                "--build-number",
                "42",
                "--sign",
                "Developer ID Application: Example",
            ]
        )
        self.assertEqual(
            [cmd[0] for cmd in self.commands],
            ["swift", "lipo", "codesign", "codesign", "ditto"],
        )
        self.assertEqual(self.commands[0][-4:], ("--arch", "arm64", "--arch", "x86_64"))
        self.assertEqual(
            self.commands[1],
            (
                "lipo",
                str(self.app / "Contents" / "MacOS" / "Timelapse"),
                "-verify_arch",
                "arm64",
                "x86_64",
            ),
        )
        self.assertIn("Developer ID Application: Example", self.commands[2])
        self.assertEqual(self.commands[3], ("codesign", "--verify", "--strict", str(self.app)))
        archive = self.app.parent / "Timelapse-v2.3.4-macos-universal.zip"
        with zipfile.ZipFile(archive) as zipped:
            info_bytes = zipped.read("Timelapse.app/Contents/Info.plist")
            self.assertEqual(info_bytes, self.signed_info)
            info = plistlib.loads(info_bytes)
            self.assertEqual(info["CFBundleShortVersionString"], "2.3.4")
            self.assertEqual(info["CFBundleVersion"], "42")
            self.assertEqual(
                zipped.read("Timelapse.app/Contents/MacOS/Timelapse"),
                b"fake executable",
            )
        checksum = archive.with_suffix(".zip.sha256")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        self.assertEqual(checksum.read_text(), f"{digest}  {archive.name}\n")
        self.assertEqual(self.source.read_bytes(), self.original)
        self.assertIn("not notarized", self.stdout.getvalue())
        # Check the sidecar with whichever standard verifier is available.
        if shutil.which("sha256sum"):
            verify = ["sha256sum", "-c", checksum.name]
        elif shutil.which("shasum"):
            verify = ["shasum", "-a", "256", "-c", checksum.name]
        else:
            return
        subprocess.run(verify, cwd=archive.parent, check=True, capture_output=True)

    def test_failed_verification_or_signing_prevents_archive(self):
        for failure in ("lipo", "codesign"):
            with self.subTest(failure=failure):
                self.commands.clear()
                self.fail_command = failure
                with self.assertRaises(subprocess.CalledProcessError):
                    build_app.main(["--archive", "--universal", "--version", "1.2.3"])
                self.assertNotIn("ditto", [cmd[0] for cmd in self.commands])

    def test_rearchive_removes_stale_files(self):
        build_app.main(["--universal"])
        archive = self.app.parent / "Timelapse-v1.2.3-macos-universal.zip"
        checksum = archive.with_suffix(".zip.sha256")
        archive.write_bytes(b"old archive")
        checksum.write_text("old checksum")

        def ditto(*command):
            self.assertFalse(archive.exists())
            self.assertFalse(checksum.exists())
            self.fake_run(*command)

        with mock.patch.object(build_app, "run", side_effect=ditto):
            self.assertEqual(build_app.archive_app(self.app, "1.2.3"), archive)
        self.assertTrue(zipfile.is_zipfile(archive))


if __name__ == "__main__":
    unittest.main()
