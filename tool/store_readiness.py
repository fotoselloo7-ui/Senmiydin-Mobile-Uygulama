"""Read-only store audit. Never requests credentials, edits .env, seeds or submits."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse
from urllib.request import urlopen
from urllib.error import HTTPError, URLError
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DOCS = [
    "GOOGLE_PLAY_SUBMISSION.md", "APP_STORE_SUBMISSION.md", "GOOGLE_PLAY_DATA_SAFETY.md",
    "APPLE_PRIVACY_LABELS.md", "PERMISSIONS.md", "BACKGROUND_LOCATION_DECLARATION.md",
    "BACKGROUND_LOCATION_REVIEW_VIDEO.md", "UGC_MODERATION.md", "ACCOUNT_DELETION.md",
    "CONTENT_RATING.md", "SCREENSHOT_PLAN.md", "FEATURE_GRAPHIC_BRIEF.md",
    "REQUIRED_REAL_INFORMATION.md", "REVIEW_ACCOUNT.md", "SDK_AUDIT.md",
    "DATA_EVIDENCE.md", "STORE_URL_SETTINGS.md", "PUBLIC_LEGAL_AUDIT.md", "README.md",
]
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
FORBIDDEN_PERMISSIONS = {
    "android.permission.ACCESS_BACKGROUND_LOCATION", "android.permission.CAMERA",
    "android.permission.READ_MEDIA_IMAGES", "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_EXTERNAL_STORAGE", "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.RECORD_AUDIO", "android.permission.READ_CONTACTS",
    "android.permission.USE_BIOMETRIC", "android.permission.USE_FINGERPRINT",
    "com.google.android.gms.permission.AD_ID", "com.android.vending.BILLING",
}
SUFFIX = re.compile(r"millisecondsSinceEpoch|\b\d{13}\b")
BAD_SDK = re.compile(r"com\.google\.android\.gms:play-services-ads(?:[-:]|\b)|com\.google\.firebase:firebase-analytics(?:[-:]|\b)|com\.android\.billingclient:|appsflyer|com\.adjust:", re.I)


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def metadata_errors(data: dict) -> list[str]:
    errors = []
    fields = [
        ("google_play", "name", 30), ("google_play", "short_description", 80),
        ("google_play", "description", 4000), ("app_store", "name", 30),
        ("app_store", "subtitle", 30), ("app_store", "promotional_text", 170),
        ("app_store", "description", 4000), ("app_store", "keywords", 100),
    ]
    for platform, key, limit in fields:
        value = data.get(platform, {}).get(key, "")
        if not isinstance(value, str) or not value or len(value) > limit:
            errors.append(platform + "." + key)
    keywords = data.get("app_store", {}).get("keywords", "")
    if not isinstance(keywords, str) or len(keywords.encode("utf-8")) > 100:
        errors.append("app_store.keywords_utf8")
    return errors


def aggregate(rows: list[dict]) -> str:
    statuses = {row["status"] for row in rows}
    return next((value for value in ["FAIL", "MISSING", "WAITING"] if value in statuses), "READY")


def audit(skip_runtime: bool = False) -> dict:
    rows = []
    evidence: dict = {}
    proof_path = ROOT / ".local/store-operator-verification.json"
    proof = json.loads(proof_path.read_text(encoding="utf-8")) if proof_path.is_file() else {}
    confirmations = proof.get("confirmations", {})

    def manual(name: str, key: str, default: str, detail: str) -> None:
        item = confirmations.get(key, {})
        reference = item.get("evidence_file", "")
        candidate = (ROOT / reference).resolve() if isinstance(reference, str) and reference else None
        verified = item.get("confirmed") is True and candidate is not None and candidate.is_file() and "GERÇEK" not in reference
        add(name, "READY" if verified else default, "Operator attestation with an existing evidence file; not independently verified by this script." if verified else detail)

    def add(name: str, status: str, detail: str) -> None:
        rows.append({"check": name, "status": status, "detail": detail})

    for name in DOCS:
        path = ROOT / "docs/store" / name
        add("Document: " + name, "READY" if path.is_file() and path.stat().st_size > 100 else "FAIL", "Required store document.")
    add("Branding requirements", "READY" if (ROOT / "docs/BRANDING_REQUIREMENTS.md").is_file() else "FAIL", "Master requirements; no artwork generated.")
    metadata = json.loads(read("docs/store/STORE_METADATA.json"))
    errors = metadata_errors(metadata)
    add("Metadata limits", "FAIL" if errors else "READY", ", ".join(errors) if errors else "Character and Apple UTF-8 byte limits passed.")
    evidence["metadata_lengths"] = {p: {k: {"characters": len(v), "utf8_bytes": len(v.encode("utf-8"))} for k, v in metadata[p].items() if isinstance(v, str)} for p in ["google_play", "app_store"]}
    for platform, filename in [("google_play", "GOOGLE_PLAY_SUBMISSION.md"), ("app_store", "APP_STORE_SUBMISSION.md")]:
        body = read("docs/store/" + filename)
        keys = ["name", "short_description", "description"] if platform == "google_play" else ["name", "subtitle", "promotional_text", "description", "keywords"]
        add("Copy consistency: " + platform, "READY" if all(metadata[platform][k] in body for k in keys) else "FAIL", "Copy blocks match machine-readable metadata.")

    pubspec = read("pubspec.yaml")
    gradle = read("android/app/build.gradle.kts")
    xcode = read("ios/Runner.xcodeproj/project.pbxproj")
    add("Application IDs and version", "READY" if 'applicationId = "com.senmiydin.app"' in gradle and "PRODUCT_BUNDLE_IDENTIFIER = com.senmiydin.app;" in xcode and "version: 0.1.0+1" in pubspec else "FAIL", "com.senmiydin.app; 0.1.0+1.")
    production = json.loads(read("config/production.json"))
    endpoint = urlparse(production.get("API_BASE_URL", ""))
    api = read("lib/core/api_config.dart")
    safe_endpoint = endpoint.scheme == "https" and endpoint.hostname not in {None, "localhost", "127.0.0.1", "10.0.2.2"} and not endpoint.username and not endpoint.password
    release_branch = re.search(r"defaultValue:\s*kReleaseMode\s*\?\s*'https://", api)
    add("Release API has no debug endpoint", "READY" if safe_endpoint and release_branch and "!kReleaseMode" in api else "FAIL", "HTTPS release default and runtime URI guard; actual live domain remains unverified.")
    main = read("lib/main.dart")
    auth = read("lib/screens/auth.dart")
    add("Normal app authentication guards", "READY" if "AppStore(api: ApiClient())" in main and "store.connected &&" in main and "if (store.connected && !store.authenticated)" in auth else "FAIL", "Real API is default; Explore does not open mock home for unauthenticated API users.")
    active_tests = [p for p in (ROOT / "integration_test").glob("*.dart") if ".sync-conflict-" not in p.name]
    bad_files = [p.name for p in active_tests if SUFFIX.search(p.read_text(encoding="utf-8"))]
    add("Device-test suffix source", "FAIL" if bad_files else "READY", ", ".join(bad_files) if bad_files else "No timestamp suffix in active device fixture sources.")
    settings_source = read("lib/screens/settings.dart")
    add("Onboarding disclosure before permission", "READY" if auth.find("Geçtiğim Yerler başlangıçta kapalıdır") >= 0 and auth.find("Geçtiğim Yerler başlangıçta kapalıdır") < auth.find("DeviceLocationRow(enabled: !busy)") else "FAIL", "Normal onboarding disclosure precedes device permission action.")
    add("Platform location disclosure", "READY" if all(s in settings_source for s in ["sunucuya gönderilir", "hikâyeleri önermek", "iOS sürümünde arka planda"]) else "FAIL", "Purpose, off-device transfer and iOS foreground-only scope stated.")
    manual("Background disclosure prominence", "background_disclosure_reviewed", "WAITING", "Normal onboarding and activation disclosure present; final Google policy/video review remains open. No Home/new screen added.")

    ios = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
    add("iOS permission configuration", "READY" if "NSLocationWhenInUseUsageDescription" in ios and "location" not in ios.get("UIBackgroundModes", []) and "NSLocationAlwaysAndWhenInUseUsageDescription" not in ios and ("NSUserTrackingUsageDescription" in ios) == ("GADApplicationIdentifier" in ios) else "FAIL", "When In Use; no background location. The ATT usage text exists exactly when AdMob (GADApplicationIdentifier) is integrated. Remote-notification is distinct.")

    merged = ROOT / "build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml"
    if merged.is_file():
        tree = ET.parse(merged).getroot()
        permissions = sorted(n.get(ANDROID_NS + "name", "") for n in tree.findall("uses-permission"))
        forbidden = sorted(p for p in permissions if p in FORBIDDEN_PERMISSIONS or ".AD_SERVICES_" in p)
        application = tree.find("application")
        evidence["android_permissions"] = permissions
        add("Merged release permissions", "FAIL" if forbidden else "READY", ", ".join(forbidden) if forbidden else "Location FGS present; no ads/background/camera/wide-media permissions.")
        required = {"android.permission.ACCESS_COARSE_LOCATION", "android.permission.ACCESS_FINE_LOCATION", "android.permission.FOREGROUND_SERVICE_LOCATION", "android.permission.POST_NOTIFICATIONS"}
        add("Required Android configuration", "READY" if required.issubset(permissions) and application is not None and application.get(ANDROID_NS + "usesCleartextTraffic") == "false" else "FAIL", "Expected location/notification permissions; release cleartext disabled.")
    else:
        add("Merged release permissions", "WAITING", "Run -RefreshAndroidAudit; source-only inspection is insufficient.")
    deps = ROOT / ".local/store-android-dependencies.log"
    android_inputs = [ROOT / p for p in ["pubspec.lock", "android/app/build.gradle.kts", "android/build.gradle.kts", "android/settings.gradle.kts", "android/app/src/main/AndroidManifest.xml"]]
    android_inputs += list((ROOT / "android/app/src/release").rglob("*"))
    latest_input = max(path.stat().st_mtime for path in android_inputs if path.is_file())
    fresh_android = merged.is_file() and deps.is_file() and min(merged.stat().st_mtime, deps.stat().st_mtime) >= latest_input
    add("Android audit evidence freshness", "READY" if fresh_android else "WAITING", "Evidence timestamps cover current native inputs." if fresh_android else "Native inputs changed or evidence absent; run -RefreshAndroidAudit.")
    if deps.is_file() and "BUILD SUCCESSFUL" in deps.read_text(encoding="utf-8", errors="replace"):
        text = deps.read_text(encoding="utf-8", errors="replace")
        add("Android ads/analytics SDK audit", "FAIL" if BAD_SDK.search(text) else "READY", "Resolved release dependency tree inspected. Measurement connector is not the Analytics engine.")
    else:
        add("Android dependency tree", "WAITING", "Run -RefreshAndroidAudit.")

    cfg = ROOT / ".dart_tool/package_config.json"
    manifest_inventory = []
    if cfg.is_file():
        for package in json.loads(cfg.read_text(encoding="utf-8"))["packages"]:
            uri = package["rootUri"]
            base = Path(unquote(urlparse(uri).path).lstrip("/")) if uri.startswith("file:") else (cfg.parent / uri).resolve()
            for folder in ["ios", "darwin"]:
                directory = base / folder
                if not directory.exists():
                    continue
                for path in directory.rglob("PrivacyInfo.xcprivacy"):
                    values = plistlib.loads(path.read_bytes())
                    manifest_inventory.append({"package": package["name"], "version": base.name.removeprefix(package["name"] + "-"), "path": path.relative_to(base).as_posix(), "tracking": values.get("NSPrivacyTracking"), "required_reason_apis": values.get("NSPrivacyAccessedAPITypes", [])})
        add("Source iOS SDK privacy manifests", "READY" if manifest_inventory else "WAITING", f"{len(manifest_inventory)} iOS/Darwin source manifests inspected; not an aggregate archive report.")
    else:
        add("Source iOS SDK privacy manifests", "WAITING", "Flutter package resolution unavailable.")
    evidence["ios_source_manifests"] = manifest_inventory
    evidence["source_hashes"] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in ["pubspec.lock", "android/app/src/main/AndroidManifest.xml", "ios/Runner/Info.plist", "lib/screens/settings.dart", "lib/screens/auth.dart", "lib/core/navigation.dart"]}
    manual("iOS archive / SDK signatures / Privacy Report", "ios_archive_privacy_verified", "WAITING", "Requires Mac/Xcode and resolved native frameworks; no fabricated app-level reason declarations.")
    manual("Final branding / store screenshots", "final_artwork_approved", "WAITING", "Approved square/horizontal masters and final store artwork not supplied; none generated.")
    manual("Review account", "review_account_prepared", "WAITING", "Production normal-role accounts must be created manually; no password stored in source.")
    manual("Production log / backup retention", "retention_policy_reviewed", "MISSING", "Real operator retention/processor policy is required, including search query logs.")
    manual("Live HTTPS legal/support URLs", "live_urls_verified", "MISSING", "Source routes exist; domain ownership, TLS and published real operator content require deployment.")

    manual("Child safety contact and response protocol", "child_safety_operations_verified", "MISSING", "Real safety contact and response/reporting process are required.")
    signing = ROOT / "android/key.properties"
    add("Android release signing", "WAITING" if signing.is_file() else "MISSING", "Configuration file present; signature not validated." if signing.is_file() else "Real signing configuration absent. No key generated.")
    local_defines = ROOT / "config/production.local.json"
    add("Mobile provider configuration", "WAITING" if local_defines.is_file() else "MISSING", "Ignored configuration present; live delivery/OAuth requires verification." if local_defines.is_file() else "Real Firebase/OAuth public identifiers absent.")

    if skip_runtime:
        add("Runtime legal/settings audit", "WAITING", "Explicitly skipped; no deployment readiness claim.")
    else:
        php = shutil.which("php")
        if php:
            try:
                process = subprocess.run([php, str(ROOT / "tool/store_backend_audit.php")], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
                runtime = json.loads(process.stdout)
                evidence["backend"] = runtime
                if runtime.get("status") == "FAIL":
                    add("Backend audit bootstrap", "FAIL", "Audit CLI did not bootstrap; no raw exception or secret printed.")
                else:
                    add("Backend runtime", runtime.get("status", "MISSING"), runtime.get("reason", "Read-only database/settings audit."))
                state = runtime.get("settings") or {}
                if state:
                    add("Real support contact", "READY" if state["support_email_real"] else "MISSING", "Backend support contact configuration.")
                    add("Moderation filter configuration", "READY" if state["banned_words_configured"] else "MISSING", "Filtering mechanism exists; curated real word policy must be configured.")
                    for key in ["app_store_url", "play_store_url"]:
                        item = state[key]
                        add(key, "FAIL" if not item["valid"] else ("READY" if item["configured"] else "WAITING"), "Configured URL syntax validated." if item["configured"] else "Blank link is legitimate; public UI must show Yakında.")
                legal = runtime.get("legal") or {}
                reviewed = bool(legal) and all(not item["uses_default"] and not item["placeholder"] for item in legal.values())
                add("Real legal CMS", "READY" if reviewed else "MISSING", "Default/filler legal content must not be accepted as production ready.")
                add("Published CSAE standard", "READY" if any(item["csae_standard"] for item in legal.values()) else "MISSING", "Social app child-safety standard and real operational contact required.")
                if runtime.get("visible_demo_suffix_free") is not None:
                    add("Current local Demo suffix", "READY" if runtime["visible_demo_suffix_free"] else "FAIL", "Only known local Demo identities inspected; no records modified.")
                for item in runtime.get("readiness", []):
                    status = "READY" if item["status"] == "OK" else "MISSING"
                    add("Production: " + item["check"], status, "Existing app:check result; local development is not production.")
            except (OSError, ValueError, subprocess.TimeoutExpired):
                add("Backend runtime", "MISSING", "Audit unavailable; no raw environment or exception printed.")
        else:
            add("Backend runtime", "WAITING", "PHP CLI unavailable.")
        for route in ["gizlilik", "kvkk", "kullanim-kosullari", "topluluk-kurallari", "hesap-silme", "iletisim"]:
            try:
                with urlopen("http://127.0.0.1:8000/" + route, timeout=8) as response:
                    body = response.read().decode("utf-8")
                    code = response.status
                add("Local public route /" + route, "READY" if code == 200 else "FAIL", f"GET HTTP {code}; local only, no form submitted.")
                if route == "iletisim":
                    add("Empty store CTA safety", "FAIL" if 'href=""' in body else "READY", "No empty href in rendered local page; source renders disabled Yakında for blank settings.")
            except HTTPError as error:
                add("Local public route /" + route, "FAIL", f"HTTP {error.code}; public GET should be reachable.")
            except (URLError, TimeoutError, OSError):
                add("Local public route /" + route, "WAITING", "Local server unavailable; source route audited.")
    return {"checked_at": datetime.now(timezone.utc).isoformat(), "overall": aggregate(rows), "scope": "Store documentation/source/runtime audit; no submission or credential creation.", "counts": dict(Counter(row["status"] for row in rows)), "checks": rows, "evidence": evidence}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-runtime", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        report = audit(args.skip_runtime)
    except Exception:
        report = {"checked_at": datetime.now(timezone.utc).isoformat(), "overall": "FAIL", "scope": "Audit did not complete; no readiness claim.", "counts": {"FAIL": 1}, "checks": [{"check": "Audit completion", "status": "FAIL", "detail": "Inspect source/config syntax without exposing secrets; incomplete prior results replaced."}], "evidence": {}}
    target = ROOT / "docs/store/STORE_READINESS_REPORT.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Store readiness sonucu", "", "Genel sonuç: **" + report["overall"] + "**", "", "Bu sonuç mağazaya gönderim/mağaza onayı değildir. Credential veya görsel üretilmedi.", "", "| Kontrol | Durum | Açıklama |", "|---|---|---|"]
    lines += ["| " + row["check"].replace("|", "/") + " | " + row["status"] + " | " + row["detail"].replace("|", "/") + " |" for row in report["checks"]]
    (target.parent / "STORE_READINESS_REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(report, ensure_ascii=False))
    else:
        for row in report["checks"]:
            print(row["status"] + " | " + row["check"] + " | " + row["detail"])
        print("RESULT: " + report["overall"] + " " + json.dumps(report["counts"]))
    return 1 if report["overall"] == "FAIL" else (0 if report["overall"] == "READY" else 2)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
