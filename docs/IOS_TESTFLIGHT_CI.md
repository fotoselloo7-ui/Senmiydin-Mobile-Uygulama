# iOS TestFlight (GitHub Actions)

Windows cannot archive iOS, so `.github/workflows/ios-testflight.yml` builds, signs and uploads on a macOS runner
(Actions → *iOS TestFlight* → *Run workflow*, or `gh workflow run ios-testflight.yml`).

**Signing:** Apple cloud-managed signing with an App Store Connect API key ("SenMiydin CI", Admin, Key ID `945723RZ4R`):
`xcodebuild -allowProvisioningUpdates` creates the distribution certificate/profile itself and `-exportArchive` with
`destination = upload` sends the build to App Store Connect (TestFlight). No `.p12` or hand-made profile is used.

**Repository secrets already set (15 Nov 2026):** `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`, `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64`, `IOS_OAUTH_XCCONFIG_BASE64`,
`PRODUCTION_CONFIG_JSON_BASE64`. The originals are in the git-ignored `secrets/` folder (see `secrets/README.md`).

**Status: WAITING FOR GITHUB ACTIONS BILLING.** The first run (43734665363) never started: "recent account payments have
failed or your spending limit needs to be increased" — the free plan's included usage ($13.83) is used up this month
(macOS minutes are metered). Fix by adding a spending limit/payment method (GitHub → Settings → Billing → Budgets), or
make the repository public (free minutes), or run the same steps on a Mac. Then re-run the workflow. The iOS build
itself is untested until it runs once (Pods, Firebase, Sign in with Apple, AdMob), so expect a fix round.

The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are required.
