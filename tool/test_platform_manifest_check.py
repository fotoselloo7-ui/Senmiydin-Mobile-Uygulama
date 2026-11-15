"""Tests for tool/platform_manifest_check.py with small synthetic merged manifests (no Gradle needed)."""
import tempfile
import unittest
from pathlib import Path

import platform_manifest_check as check

NS = 'xmlns:android="http://schemas.android.com/apk/res/android"'

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECORD_AUDIO",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
]


def manifest(*, cleartext="false", backup="false", permissions=PERMISSIONS, ads="ca-app-pub-1111111111111111~2222222222", extra_application="", extra_root="", debuggable=None) -> str:
    uses = "\n".join(f'<uses-permission android:name="{name}" />' for name in permissions)
    debug = f' android:debuggable="{debuggable}"' if debuggable else ""
    return f"""<manifest {NS} package="com.senmiydin.app">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />
  {uses}
  {extra_root}
  <application android:allowBackup="{backup}" android:usesCleartextTraffic="{cleartext}"{debug}>
    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="{ads}" />
    <meta-data android:name="firebase_messaging_auto_init_enabled" android:value="false" />
    <meta-data android:name="firebase_analytics_collection_enabled" android:value="false" />
    <activity android:name="com.senmiydin.app.MainActivity" android:exported="true">
      <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
    </activity>
    <activity android:name="com.google.android.gms.ads.AdActivity" android:exported="false" />
    <provider android:name="com.google.android.gms.ads.MobileAdsInitProvider" android:exported="false" />
    <provider android:name="io.flutter.plugins.imagepicker.ImagePickerFileProvider" android:exported="false" />
    <service android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService" android:exported="false" />
    <service android:name="com.google.firebase.messaging.FirebaseMessagingService" android:exported="false" />
    <service android:name="com.baseflow.geolocator.GeolocatorLocationService" android:exported="false" android:foregroundServiceType="location" />
    {extra_application}
  </application>
</manifest>"""


def run(text: str) -> check.Report:
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "AndroidManifest.xml"
        path.write_text(text, encoding="utf-8")
        return check.check_android(path)


def failed(report: check.Report) -> set[str]:
    return {row["check"] for row in report.rows if row["status"] == "FAIL"}


class AndroidManifestTests(unittest.TestCase):
    def test_a_correct_manifest_passes(self):
        report = run(manifest())
        self.assertEqual(report.status, "OK", report.rows)

    def test_the_google_sample_admob_id_is_a_missing_external_credential_not_a_code_failure(self):
        report = run(manifest(ads=check.GOOGLE_SAMPLE_ADMOB_ANDROID))
        self.assertEqual(report.status, "MISSING")
        self.assertEqual(failed(report), set())

    def test_cleartext_in_release_fails(self):
        self.assertIn("Cleartext traffic off", failed(run(manifest(cleartext="true"))))

    def test_enabled_backup_fails(self):
        self.assertIn("Backups disabled", failed(run(manifest(backup="true"))))

    def test_a_debuggable_release_fails(self):
        self.assertIn("Not debuggable", failed(run(manifest(debuggable="true"))))

    def test_the_microphone_permission_is_required_for_voice_messages(self):
        names = [name for name in PERMISSIONS if not name.endswith("RECORD_AUDIO")]
        bad = failed(run(manifest(permissions=names)))
        self.assertIn("Microphone permission (voice messages)", bad)
        self.assertIn("Required permissions", bad)

    def test_unexpected_permissions_fail(self):
        names = PERMISSIONS + ["android.permission.READ_CONTACTS", "android.permission.ACCESS_BACKGROUND_LOCATION"]
        self.assertIn("No unexpected permissions", failed(run(manifest(permissions=names))))

    def test_unexpected_exported_component_and_open_provider_fail(self):
        extra = '<receiver android:name="com.example.Open" android:exported="true" /><provider android:name="com.example.P" android:exported="true" />'
        bad = failed(run(manifest(extra_application=extra)))
        self.assertIn("Exported components are the expected ones", bad)
        self.assertIn("Providers are not exported", bad)

    def test_androidx_infrastructure_is_accepted_only_with_its_permission(self):
        guarded = '<receiver android:name="androidx.profileinstaller.ProfileInstallReceiver" android:exported="true" android:permission="android.permission.DUMP" />'
        open_one = '<receiver android:name="androidx.profileinstaller.ProfileInstallReceiver" android:exported="true" />'
        self.assertEqual(failed(run(manifest(extra_application=guarded))), set())
        self.assertIn("Exported components are the expected ones", failed(run(manifest(extra_application=open_one))))

    def test_web_links_and_unknown_schemes_fail_until_they_are_reviewed(self):
        link = '<activity android:name="com.example.Link" android:exported="false"><intent-filter><data android:scheme="https" android:host="senmiydin.com" /></intent-filter></activity>'
        self.assertIn("Deep link schemes", failed(run(manifest(extra_application=link))))

    def test_verified_app_links_for_shared_posts_and_notes_are_allowed(self):
        link = (
            '<activity android:name="com.example.Link" android:exported="false"><intent-filter android:autoVerify="true">'
            '<data android:scheme="https" android:host="senmiydin.com" android:pathPrefix="/p/" />'
            '<data android:scheme="https" android:host="senmiydin.com" android:pathPrefix="/n/" /></intent-filter></activity>'
        )
        self.assertEqual(failed(run(manifest(extra_application=link))), set())

    def test_app_links_without_auto_verify_or_with_other_paths_fail(self):
        unverified = '<activity android:name="com.example.Link" android:exported="false"><intent-filter><data android:scheme="https" android:host="senmiydin.com" android:pathPrefix="/p/" /></intent-filter></activity>'
        self.assertIn("App Links are auto-verified", failed(run(manifest(extra_application=unverified))))
        broad = '<activity android:name="com.example.Link" android:exported="false"><intent-filter android:autoVerify="true"><data android:scheme="https" android:host="senmiydin.com" android:pathPrefix="/admin/" /></intent-filter></activity>'
        self.assertIn("Deep link schemes", failed(run(manifest(extra_application=broad))))

    def test_local_endpoints_must_not_leak_into_the_release_manifest(self):
        leak = '<meta-data android:name="api" android:value="http://10.0.2.2:8000" />'
        self.assertIn("No debug / local endpoints in the manifest", failed(run(manifest(extra_application=leak))))

    def test_a_missing_manifest_fails_instead_of_passing_silently(self):
        report = check.check_android(Path("does-not-exist.xml"))
        self.assertEqual(report.status, "FAIL")


class IosStaticTests(unittest.TestCase):
    def test_the_repository_passes_or_only_lacks_external_credentials(self):
        report = check.check_ios()
        self.assertNotEqual(report.status, "FAIL", [row for row in report.rows if row["status"] == "FAIL"])
        self.assertTrue(any(row["check"] == "Scope" and "no Xcode build" in row["detail"] for row in report.rows))


if __name__ == "__main__":
    unittest.main()
