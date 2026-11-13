"""Read actual provider config files into the ignored mobile build configuration."""
import argparse
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--android", type=Path, help="Actual google-services.json")
parser.add_argument("--ios", type=Path, help="Actual GoogleService-Info.plist")
args = parser.parse_args()
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
output = ROOT / "config/production.local.json"
output.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
print("Created ignored config/production.local.json from supplied provider files; no values printed.")
