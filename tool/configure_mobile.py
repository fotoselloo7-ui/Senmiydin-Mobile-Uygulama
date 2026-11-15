"""Read actual provider config files into the ignored mobile build configuration."""
import argparse
import json
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--android", type=Path, help="Actual google-services.json")
parser.add_argument("--ios", type=Path, help="Actual GoogleService-Info.plist")
parser.add_argument("--admob-android-app-id", help="Real AdMob Android application id (ca-app-pub-…~…)")
parser.add_argument("--admob-ios-app-id", help="Real AdMob iOS application id (ca-app-pub-…~…)")
parser.add_argument("--admob-android-native-unit", help="Real AdMob Android native ad unit id (ca-app-pub-…/…)")
parser.add_argument("--admob-ios-native-unit", help="Real AdMob iOS native ad unit id (ca-app-pub-…/…)")
args = parser.parse_args()
SAMPLE_PUBLISHER = "3940256099942544"  # Google's documented sample publisher: never a production id


def admob(value, separator, label):
    pattern = r"ca-app-pub-(\d{16})" + re.escape(separator) + r"(\d{10})"
    match = re.fullmatch(pattern, value or "")
    if not match:
        raise ValueError(f"{label} is not a valid AdMob id")
    if match.group(1) == SAMPLE_PUBLISHER:
        raise ValueError(f"{label} is Google's sample id; supply the real production id")
    return value


xcconfig_lines = []
settings = json.loads((ROOT / "config/production.json").read_text(encoding="utf-8"))
if args.android:
    source = json.loads(args.android.read_text(encoding="utf-8"))
    client = next(item for item in source["client"] if item["client_info"]["android_client_info"]["package_name"] == "com.senmiydin.app")
    settings.update(FCM_PROJECT_ID=source["project_info"]["project_id"],
                    FCM_SENDER_ID=source["project_info"]["project_number"],
                    FCM_ANDROID_APP_ID=client["client_info"]["mobilesdk_app_id"],
                    FCM_ANDROID_API_KEY=client["api_key"][0]["current_key"])
    web_clients = [item["client_id"] for item in client.get("oauth_client", []) if item.get("client_type") == 3]
    if web_clients:
        settings["GOOGLE_WEB_CLIENT_ID"] = web_clients[0]
if args.ios:
    with args.ios.open("rb") as stream:
        source = plistlib.load(stream)
    if source["BUNDLE_ID"] != "com.senmiydin.app":
        raise ValueError("Unexpected iOS bundle identifier")
    if settings.get("FCM_PROJECT_ID", source["PROJECT_ID"]) != source["PROJECT_ID"]:
        raise ValueError("Android and iOS Firebase projects differ")
    settings.update(FCM_PROJECT_ID=source["PROJECT_ID"], FCM_SENDER_ID=source["GCM_SENDER_ID"],
                    FCM_IOS_APP_ID=source["GOOGLE_APP_ID"], FCM_IOS_API_KEY=source["API_KEY"])
    if source.get("CLIENT_ID"):
        settings["GOOGLE_IOS_CLIENT_ID"] = source["CLIENT_ID"]
    if source.get("REVERSED_CLIENT_ID"):
        (ROOT / "ios/Flutter/OAuth.xcconfig").write_text(
            "GOOGLE_REVERSED_CLIENT_ID = " + source["REVERSED_CLIENT_ID"] + "\n", encoding="utf-8")
if args.admob_android_app_id:
    settings["ADMOB_APP_ID_ANDROID"] = admob(args.admob_android_app_id, "~", "Android AdMob app id")
if args.admob_android_native_unit:
    settings["ADMOB_NATIVE_AD_UNIT_ANDROID"] = admob(args.admob_android_native_unit, "/", "Android native ad unit")
if args.admob_ios_native_unit:
    settings["ADMOB_NATIVE_AD_UNIT_IOS"] = admob(args.admob_ios_native_unit, "/", "iOS native ad unit")
if args.admob_ios_app_id:
    settings["ADMOB_APP_ID_IOS"] = admob(args.admob_ios_app_id, "~", "iOS AdMob app id")
    xcconfig_lines.append("ADMOB_APP_ID_IOS = " + settings["ADMOB_APP_ID_IOS"])
if xcconfig_lines:
    target = ROOT / "ios/Flutter/OAuth.xcconfig"
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    keep = [row for row in existing.splitlines() if not any(row.startswith(line.split(" =")[0]) for line in xcconfig_lines)]
    target.write_text(chr(10).join(keep + xcconfig_lines) + chr(10), encoding="utf-8")
output = ROOT / "config/production.local.json"
output.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
print("Created ignored config/production.local.json from supplied provider files; no values printed.")
