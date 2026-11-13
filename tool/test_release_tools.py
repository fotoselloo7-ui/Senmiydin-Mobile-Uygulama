import tempfile
import unittest
import zipfile
from pathlib import Path
from release_safety import secret_path, inline_findings, audit_zip

class ReleaseToolsTest(unittest.TestCase):
    def test_examples_are_allowed_and_private_paths_rejected(self):
        self.assertFalse(secret_path("backend/.env.example"))
        self.assertFalse(secret_path("android/key.properties.example"))
        for path in ["backend/.env", "backend/.env.production", "private/key.p8", "android/release.jks", "backup/users.sql.gz"]:
            self.assertTrue(secret_path(path), path)

    def test_secret_findings_never_return_matched_values(self):
        value = "synthetic-test-only-value"
        report = inline_findings(("MAIL_PASSWORD=" + value).encode())
        self.assertTrue(report)
        self.assertNotIn(value, str(report))

    def test_zip_audit_fails_closed_on_runtime_or_secret_files(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("artisan", "<?php")
                archive.writestr("public/index.php", "<?php")
                archive.writestr(".env", "MAIL_PASSWORD=synthetic-test-only")
            result = audit_zip(path)
            self.assertEqual(result["status"], "FAIL")
            self.assertTrue(any(row["kind"] == "forbidden-archive-path" for row in result["findings"]))
            self.assertNotIn("synthetic-test-only", str(result))

if __name__ == "__main__":
    unittest.main()
