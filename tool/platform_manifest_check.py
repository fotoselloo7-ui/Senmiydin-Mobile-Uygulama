"""Release sanity checks for the platform manifests.

  android  Reads the REAL merged *release* manifest (the one Gradle produces after merging the app manifest with every
           plugin / SDK manifest, `:app:processReleaseMainManifest`) and fails when the release would ship something
           wrong. This is not the source `src/main/AndroidManifest.xml`: plugins add permissions, providers and
           services that only show up after merging.
  ios      Static sanity of Info.plist, the privacy manifest, the localized permission strings and the Xcode project.
           It reads files only. It does NOT build, sign or archive anything: that needs Xcode on a Mac
           (see docs/IOS_MAC_HANDOFF.md).

Exit codes: 0 all good, 1 FAIL (something is wrong in the code/config), 2 MISSING (an external credential is still a
documented placeholder, e.g. the Google sample AdMob app id). FAIL wins over MISSING.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
PACKAGE = "com.senmiydin.app"

MERGED_MANIFEST = ROOT / "build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml"

REQUIRED_PERMISSIONS = {
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECORD_AUDIO",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
}

# Permissions the product never needs. Seeing one means a plugin or a copy/paste added it silently.
FORBIDDEN_PERMISSIONS = {
    "android.permission.ACCESS_BACKGROUND_LOCATION": "background location is not used",
    "android.permission.FOREGROUND_SERVICE": "no foreground service: Places I Passed records only while the app is open",
    "android.permission.FOREGROUND_SERVICE_LOCATION": "no foreground service: Places I Passed records only while the app is open",
    "android.permission.READ_EXTERNAL_STORAGE": "photos go through the system picker",
    "android.permission.WRITE_EXTERNAL_STORAGE": "photos go through the system picker",
    "android.permission.MANAGE_EXTERNAL_STORAGE": "all-files access is not used",
    "android.permission.READ_MEDIA_IMAGES": "photos go through the system picker",
    "android.permission.READ_MEDIA_VIDEO": "no video",
    "android.permission.READ_CONTACTS": "contacts are not used",
    "android.permission.READ_PHONE_STATE": "no phone state",
    "android.permission.READ_SMS": "no SMS",
    "android.permission.SYSTEM_ALERT_WINDOW": "no overlays",
    "android.permission.USE_BIOMETRIC": "removed on purpose",
    "android.permission.USE_FINGERPRINT": "removed on purpose",
    "android.permission.ACCESS_ADSERVICES_ATTRIBUTION": "Privacy Sandbox attribution is not used",
    "android.permission.ACCESS_ADSERVICES_TOPICS": "Privacy Sandbox topics are not used",
    "android.permission.CAMERA": "the camera is opened through the system camera app (no CAMERA permission)",
    "android.permission.REQUEST_INSTALL_PACKAGES": "no installs",
}

# Exported components that are expected (entry point, OAuth callback, Firebase / Google SDK entry points).
EXPORTED_ALLOWED = {
    "com.senmiydin.app.MainActivity",
    "com.aboutyou.dart_packages.sign_in_with_apple.SignInWithAppleCallback",
    "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver",
    "com.google.firebase.iid.FirebaseInstanceIdReceiver",
    "com.google.android.gms.auth.api.signin.RevocationBoundService",
}
# AndroidX infrastructure that is exported by design but only callable by the system, because it demands a signature /
# system permission. They are accepted only while that permission is still on the component.
EXPORTED_IF_PERMISSION_PROTECTED = {
    "androidx.work.impl.background.systemjob.SystemJobService": "android.permission.BIND_JOB_SERVICE",
    "androidx.work.impl.diagnostics.DiagnosticsReceiver": "android.permission.DUMP",
    "androidx.profileinstaller.ProfileInstallReceiver": "android.permission.DUMP",
}
ALLOWED_URL_SCHEMES = {"signinwithapple"}
ALLOWED_LINK_PREFIXES = {"/p/", "/n/"}
GOOGLE_SAMPLE_ADMOB_ANDROID = "ca-app-pub-3940256099942544~3347511713"
GOOGLE_SAMPLE_ADMOB_IOS = "ca-app-pub-3940256099942544~1458002511"


class Report:
    def __init__(self) -> None:
        self.rows: list[dict[str, str]] = []

    def ok(self, check: str, detail: str = "") -> None:
        self.rows.append({"check": check, "status": "OK", "detail": detail})

    def fail(self, check: str, detail: str) -> None:
        self.rows.append({"check": check, "status": "FAIL", "detail": detail})

    def missing(self, check: str, detail: str) -> None:
        self.rows.append({"check": check, "status": "MISSING", "detail": detail})

    @property
    def status(self) -> str:
        statuses = {row["status"] for row in self.rows}
        return "FAIL" if "FAIL" in statuses else "MISSING" if "MISSING" in statuses else "OK"

    def expect(self, check: str, condition: bool, detail: str) -> None:
        (self.ok if condition else self.fail)(check, "" if condition else detail)


def attr(element: ET.Element, name: str) -> str | None:
    return element.get(ANDROID_NS + name)


def component_name(element: ET.Element) -> str:
    name = attr(element, "name") or ""
    return PACKAGE + name if name.startswith(".") else name


# ---------------------------------------------------------------------------------------------------------- Android
def check_android(manifest_path: Path) -> Report:
    report = Report()
    if not manifest_path.is_file():
        report.fail("Merged release manifest", f"not found: {manifest_path} (run `gradlew :app:processReleaseMainManifest`)")
        return report
    root = ET.parse(manifest_path).getroot()
    app = root.find("application")
    assert app is not None, "manifest has no <application>"

    report.expect("Package name", root.get("package") == PACKAGE, f"package is {root.get('package')!r}, expected {PACKAGE}")
    report.expect(
        "Cleartext traffic off",
        attr(app, "usesCleartextTraffic") == "false",
        f"usesCleartextTraffic={attr(app, 'usesCleartextTraffic')!r}: the release must not allow plain HTTP",
    )
    report.expect("Backups disabled", attr(app, "allowBackup") == "false", f"allowBackup={attr(app, 'allowBackup')!r}")
    report.expect("Not debuggable", attr(app, "debuggable") in (None, "false"), "android:debuggable is true in a release manifest")
    report.expect("Not testOnly", attr(app, "testOnly") in (None, "false"), "android:testOnly is set")
    report.expect(
        "No custom network security config",
        attr(app, "networkSecurityConfig") is None,
        "a networkSecurityConfig could re-allow cleartext; review it before adding",
    )

    declared = {attr(node, "name") for node in root.findall("uses-permission")}
    missing_permissions = sorted(REQUIRED_PERMISSIONS - declared)
    report.expect("Required permissions", not missing_permissions, f"missing: {', '.join(missing_permissions)}")
    report.expect("Microphone permission (voice messages)", "android.permission.RECORD_AUDIO" in declared, "RECORD_AUDIO missing")
    forbidden = {name: why for name, why in FORBIDDEN_PERMISSIONS.items() if name in declared}
    report.expect(
        "No unexpected permissions",
        not forbidden,
        "; ".join(f"{name} ({why})" for name, why in forbidden.items()),
    )

    ads_id = None
    for meta in app.findall("meta-data"):
        if attr(meta, "name") == "com.google.android.gms.ads.APPLICATION_ID":
            ads_id = attr(meta, "value")
    if not ads_id or "${" in ads_id:
        report.fail("AdMob application id", "meta-data missing or an unresolved placeholder")
    elif ads_id == GOOGLE_SAMPLE_ADMOB_ANDROID:
        report.missing(
            "AdMob application id",
            "Google sample id: pass the real id with --dart-define=ADMOB_APP_ID_ANDROID (EXTERNAL CREDENTIAL)",
        )
    else:
        report.ok("AdMob application id", "real id supplied")

    services = {component_name(node): node for node in app.findall("service")}
    receivers = {component_name(node): node for node in app.findall("receiver")}
    providers = {component_name(node): node for node in app.findall("provider")}
    activities = {component_name(node): node for node in app.findall("activity")}

    report.expect(
        "Firebase Cloud Messaging service",
        "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService" in services
        and "com.google.firebase.messaging.FirebaseMessagingService" in services,
        "the FCM services are not in the merged manifest",
    )
    report.expect(
        "Firebase auto-init stays off until consent",
        any(attr(m, "name") == "firebase_messaging_auto_init_enabled" and attr(m, "value") == "false" for m in app.findall("meta-data")),
        "firebase_messaging_auto_init_enabled must be false",
    )
    report.expect(
        "Firebase analytics collection off",
        any(attr(m, "name") == "firebase_analytics_collection_enabled" and attr(m, "value") == "false" for m in app.findall("meta-data")),
        "firebase_analytics_collection_enabled must be false",
    )
    report.expect(
        "AdMob components",
        "com.google.android.gms.ads.AdActivity" in activities and "com.google.android.gms.ads.MobileAdsInitProvider" in providers,
        "AdMob activity / init provider missing",
    )
    geolocator = services.get("com.baseflow.geolocator.GeolocatorLocationService")
    report.expect(
        "No foreground location service",
        geolocator is None,
        "GeolocatorLocationService must be removed from the merged manifest (no foreground service is used)",
    )
    exported_providers = [name for name, node in providers.items() if attr(node, "exported") == "true"]
    report.expect("Providers are not exported", not exported_providers, f"exported providers: {', '.join(exported_providers)}")
    grant_all = [name for name, node in providers.items() if attr(node, "grantUriPermissions") == "true" and attr(node, "exported") != "false"]
    report.expect("File providers grant per-URI only", not grant_all, f"review: {', '.join(grant_all)}")
    report.expect(
        "Image picker provider (photos, camera)",
        "io.flutter.plugins.imagepicker.ImagePickerFileProvider" in providers,
        "ImagePickerFileProvider missing",
    )

    exported = []
    for group in (activities, services, receivers, providers):
        for name, node in group.items():
            if attr(node, "exported") != "true":
                continue
            guard = EXPORTED_IF_PERMISSION_PROTECTED.get(name)
            if guard is not None and attr(node, "permission") == guard:
                continue
            exported.append(name)
    unexpected = sorted(set(exported) - EXPORTED_ALLOWED)
    report.expect("Exported components are the expected ones", not unexpected, f"unexpected exported: {', '.join(unexpected)}")
    implicit = [
        name
        for group in (activities, services, receivers)
        for name, node in group.items()
        if attr(node, "exported") is None and node.find("intent-filter") is not None
    ]
    report.expect("Components with intent filters declare exported", not implicit, f"implicit export: {', '.join(implicit)}")

    schemes: set[str] = set()
    bad_links: list[str] = []
    for node in app.iter("data"):
        scheme = attr(node, "scheme")
        if not scheme:
            continue
        schemes.add(scheme)
        if scheme == "https":
            # Android App Links for shared posts / Map Notes only: a real host and exactly the /p/ or /n/ prefixes.
            host = attr(node, "host") or ""
            prefix = attr(node, "pathPrefix") or ""
            if not host or "$" in host or prefix not in ALLOWED_LINK_PREFIXES:
                bad_links.append(f"{host or '*'}{prefix or '/*'}")
    report.expect(
        "Deep link schemes",
        schemes <= ALLOWED_URL_SCHEMES | {"https"} and not bad_links,
        f"unexpected URL schemes {sorted(schemes - ALLOWED_URL_SCHEMES - {'https'})} or web links {bad_links}; "
        "app links must be limited to /p/ and /n/ on the real host",
    )
    link_filters = [f for f in app.iter("intent-filter") if any(attr(d, "scheme") == "https" for d in f.findall("data"))]
    report.expect(
        "App Links are auto-verified",
        all(attr(f, "autoVerify") == "true" for f in link_filters),
        "https intent filters need android:autoVerify=\"true\" (and /.well-known/assetlinks.json on the host)",
    )
    main = activities.get("com.senmiydin.app.MainActivity")
    launcher = main is not None and any(
        attr(a, "name") == "android.intent.action.MAIN" for a in main.iter("action")
    )
    report.expect("Launcher activity", launcher, "MainActivity has no MAIN/LAUNCHER filter")

    text = manifest_path.read_text(encoding="utf-8")
    leaks = [needle for needle in ("localhost", "10.0.2.2", "127.0.0.1", "ngrok", "debug.keystore") if needle in text]
    report.expect("No debug / local endpoints in the manifest", not leaks, f"found: {', '.join(leaks)}")
    report.expect("No debug-only components", "androidx.compose.ui.tooling" not in text and "LeakCanary" not in text, "debug tooling activity merged into release")
    report.expect("Min / target SDK present", root.find("uses-sdk") is not None, "uses-sdk missing")
    return report


def build_android_manifest() -> None:
    """Gradle's merged release manifest. When an (ignored) config/production.local.json exists its values are passed the
    same way `flutter build --dart-define-from-file` does, so the manifest shows the real AdMob id instead of the sample."""
    import base64

    gradle = ROOT / "android" / ("gradlew.bat" if sys.platform == "win32" else "gradlew")
    command = [str(gradle), ":app:processReleaseMainManifest", "--console=plain", "-q"]
    local = ROOT / "config/production.local.json"
    if local.is_file():
        defines = json.loads(local.read_text(encoding="utf-8"))
        encoded = ",".join(base64.b64encode(f"{key}={value}".encode()).decode() for key, value in defines.items())
        command.append("-Pdart-defines=" + encoded)
    subprocess.run(command, cwd=ROOT / "android", check=True)


# -------------------------------------------------------------------------------------------------------------- iOS
def parse_strings(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r'\s*"([^"]+)"\s*=\s*"(.*)"\s*;\s*$', line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def check_ios() -> Report:
    report = Report()
    ios = ROOT / "ios"
    info_path = ios / "Runner/Info.plist"
    privacy_path = ios / "Runner/PrivacyInfo.xcprivacy"
    project_path = ios / "Runner.xcodeproj/project.pbxproj"
    for path in (info_path, privacy_path, project_path):
        if not path.is_file():
            report.fail("iOS files", f"missing {path.relative_to(ROOT)}")
            return report
    try:
        info = plistlib.loads(info_path.read_bytes())
        privacy = plistlib.loads(privacy_path.read_bytes())
    except Exception as error:  # a malformed plist is a release blocker
        report.fail("Property lists parse", str(error))
        return report
    report.ok("Property lists parse")

    project = project_path.read_text(encoding="utf-8", errors="replace")
    report.expect("Bundle identifier", f"PRODUCT_BUNDLE_IDENTIFIER = {PACKAGE};" in project, f"project bundle id is not {PACKAGE}")

    permissions = {
        "NSMicrophoneUsageDescription": "voice messages",
        "NSCameraUsageDescription": "camera photos",
        "NSPhotoLibraryUsageDescription": "photo picker",
        "NSLocationWhenInUseUsageDescription": "approximate location",
    }
    for key, purpose in permissions.items():
        value = info.get(key)
        report.expect(f"{key} ({purpose})", isinstance(value, str) and len(value.strip()) >= 20, "missing or too short to explain the use")
    for forbidden in ("NSLocationAlwaysAndWhenInUseUsageDescription", "NSLocationAlwaysUsageDescription", "NSContactsUsageDescription", "NSUserTrackingUsageDescription"):
        report.expect(f"No {forbidden}", forbidden not in info, "permission the product does not use")
    for localization in ("en", "tr"):
        strings_path = ios / f"Runner/{localization}.lproj/InfoPlist.strings"
        if not strings_path.is_file():
            report.fail(f"InfoPlist.strings ({localization})", "missing")
            continue
        strings = parse_strings(strings_path)
        absent = [key for key in permissions if len(strings.get(key, "")) < 20]
        report.expect(f"Localized permission texts ({localization})", not absent, f"missing: {', '.join(absent)}")
    report.expect("Localizations declared", set(info.get("CFBundleLocalizations", [])) >= {"tr", "en"}, "CFBundleLocalizations must list tr and en")

    ats = info.get("NSAppTransportSecurity", {})
    report.expect(
        "App Transport Security is not weakened",
        not ats.get("NSAllowsArbitraryLoads") and not ats.get("NSAllowsLocalNetworking") and not ats.get("NSExceptionDomains"),
        "ATS exceptions found",
    )
    modes = set(info.get("UIBackgroundModes", []))
    report.expect("Background modes are only remote-notification", modes <= {"remote-notification"}, f"unexpected: {sorted(modes - {'remote-notification'})}")
    report.expect("Firebase auto-init off", info.get("FirebaseMessagingAutoInitEnabled") is False, "FirebaseMessagingAutoInitEnabled must be false")

    ads_id = info.get("GADApplicationIdentifier", "")
    if not ads_id:
        report.fail("AdMob application id", "GADApplicationIdentifier missing")
    elif "$(" in ads_id or ads_id == GOOGLE_SAMPLE_ADMOB_IOS:
        oauth = ios / "Flutter/OAuth.xcconfig"
        configured = ""
        if oauth.is_file():
            match = re.search(r"^\s*ADMOB_APP_ID_IOS\s*=\s*(\S+)", oauth.read_text(encoding="utf-8"), re.M)
            configured = match.group(1) if match else ""
        if configured and configured != GOOGLE_SAMPLE_ADMOB_IOS and re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", configured):
            report.ok("AdMob application id", "real id in the ignored OAuth.xcconfig")
        else:
            report.missing("AdMob application id", "supplied at build time via ADMOB_APP_ID_IOS (EXTERNAL CREDENTIAL)")
    else:
        report.ok("AdMob application id", "real id in Info.plist")

    types = {row.get("NSPrivacyCollectedDataType") for row in privacy.get("NSPrivacyCollectedDataTypes", [])}
    for needed in ("NSPrivacyCollectedDataTypeAudioData", "NSPrivacyCollectedDataTypePhotosorVideos", "NSPrivacyCollectedDataTypeCoarseLocation"):
        report.expect(f"Privacy manifest declares {needed.removeprefix('NSPrivacyCollectedDataType')}", needed in types, "declare it before submitting")
    audio = [row for row in privacy.get("NSPrivacyCollectedDataTypes", []) if row.get("NSPrivacyCollectedDataType") == "NSPrivacyCollectedDataTypeAudioData"]
    report.expect(
        "Voice recordings are not tracking",
        all(row.get("NSPrivacyCollectedDataTypeTracking") is False for row in audio),
        "audio data must not be used for tracking",
    )
    report.expect("Privacy manifest has tracking domains when tracking is declared", not privacy.get("NSPrivacyTracking") or bool(privacy.get("NSPrivacyTrackingDomains")), "NSPrivacyTracking true needs NSPrivacyTrackingDomains")

    entitlements_path = ios / "Runner/Runner.entitlements"
    report.expect("Runner.entitlements present", entitlements_path.is_file(), "missing entitlements file")
    if entitlements_path.is_file():
        entitlements = plistlib.loads(entitlements_path.read_bytes())
        domains = entitlements.get("com.apple.developer.associated-domains", [])
        report.expect(
            "Universal Links (associated domains) declared",
            any(str(domain).startswith("applinks:") for domain in domains),
            "add applinks:<website domain>; the apple-app-site-association file is served once APPLE_TEAM_ID is configured",
        )
    report.expect("Handoff document present", (ROOT / "docs/IOS_MAC_HANDOFF.md").is_file(), "docs/IOS_MAC_HANDOFF.md missing")
    report.ok("Scope", "static files only: no Xcode build, signing or archive was run")
    return report


# -------------------------------------------------------------------------------------------------------------- main
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("platform", choices=["android", "ios"])
    parser.add_argument("--manifest", type=Path, default=MERGED_MANIFEST, help="merged release manifest (android)")
    parser.add_argument("--build", action="store_true", help="run Gradle first so the merged manifest is current (android)")
    parser.add_argument("--json", type=Path, help="also write the report here")
    args = parser.parse_args(argv)

    if args.platform == "android":
        if args.build:
            build_android_manifest()
        report = check_android(args.manifest)
    else:
        report = check_ios()

    for row in report.rows:
        line = f"[{row['status']:<7}] {row['check']}"
        print(line + (f" - {row['detail']}" if row["detail"] else ""))
    print(f"\n{args.platform}: {report.status}")
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps({"platform": args.platform, "status": report.status, "checks": report.rows}, indent=2), encoding="utf-8")
    return {"OK": 0, "FAIL": 1, "MISSING": 2}[report.status]


if __name__ == "__main__":
    sys.exit(main())
