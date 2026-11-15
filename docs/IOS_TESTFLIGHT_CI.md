# iOS TestFlight (GitHub Actions)

Windows cannot archive iOS, so `.github/workflows/ios-testflight.yml` builds and uploads on a macOS runner
(Actions → *iOS TestFlight* → *Run workflow*). **Durum: WAITING FOR APPLE SIGNING SECRETS** — the workflow is in the repo
but has never been run; the iOS build itself is untested (Pods, Firebase, Sign in with Apple, AdMob) until it runs once.

Required repository secrets (Settings → Secrets and variables → Actions), in the order the check step reports them:

| # | Secret | What |
|---|---|---|
| S1 | `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution certificate + private key as `.p12`, base64 (the team already has 3 distribution certificates = the limit; reuse one whose `.p12` you hold, do not revoke) |
| S2 | `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | password of that `.p12` |
| S3 | `IOS_PROVISIONING_PROFILE_BASE64` | App Store profile for `com.senmiydin.app` made with that same certificate (Sign in with Apple, Push, Associated Domains are enabled on the App ID), base64 |
| S4 | `APP_STORE_CONNECT_PRIVATE_KEY` | contents of an App Store Connect API key `.p8` (App Manager) |
| S5 | `APP_STORE_CONNECT_KEY_ID` | its Key ID |
| S6 | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (Users and Access → Integrations → App Store Connect API) |
| S7 | `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64` | `ios/Runner/GoogleService-Info.plist` (git-ignored), base64 |
| S8 | `IOS_OAUTH_XCCONFIG_BASE64` | `ios/Flutter/OAuth.xcconfig` (git-ignored), base64 |
| S9 | `PRODUCTION_CONFIG_JSON_BASE64` | `config/production.local.json` (git-ignored), base64 |

Base64 example (Git Bash): `base64 -w0 file | gh secret set NAME --repo fotoselloo7-ui/Senmiydin-Mobile-Uygulama`.

The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are required.
