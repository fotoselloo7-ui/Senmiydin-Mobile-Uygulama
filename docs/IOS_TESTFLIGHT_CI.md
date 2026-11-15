# iOS TestFlight (GitHub Actions)

Windows cannot archive iOS, so `.github/workflows/ios-testflight.yml` builds, signs and uploads on a macOS runner
(Actions → *iOS TestFlight* → *Run workflow*, or `gh workflow run ios-testflight.yml`).

**Signing:** Apple cloud-managed signing with an App Store Connect API key ("SenMiydin CI", Admin, Key ID `945723RZ4R`):
`xcodebuild -allowProvisioningUpdates` creates the distribution certificate/profile itself and `-exportArchive` with
`destination = upload` sends the build to App Store Connect (TestFlight). No `.p12` or hand-made profile is used.

**Repository secrets already set (15 Nov 2026):** `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`, `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64`, `IOS_OAUTH_XCCONFIG_BASE64`,
`PRODUCTION_CONFIG_JSON_BASE64`. The originals are in the git-ignored `secrets/` folder (see `secrets/README.md`).

**Status (15 Nov 2026): WORKING.** Run 43741862685 built, signed and uploaded build **0.1.0 (15)** to App Store Connect; it is
VALID, export compliance is set (no non-exempt encryption), it is attached to the App Store version (version string changed
from 1.0 to 0.1.0 to match the build) and available to the TestFlight group "Internal" (account holder added). Fixes that
were needed: public repo (free macOS minutes), archive unsigned (the team has no registered device for a development
profile) and strip vendor signatures from the embedded frameworks so export re-signs them (Google Mobile Ads / UMP).
Build number is `GITHUB_RUN_NUMBER + 10`, so every run is unique. `tool/asc_api.py` talks to the App Store Connect API.

**Still needed before "Add for Review":** review contact phone number, copyright confirmation, content-rights and IDFA
answers, App Privacy questionnaire (web only), reviewer sign-in (`secrets/review/REVIEW_ACCOUNT.txt`) and a deployed backend.

The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are required.
