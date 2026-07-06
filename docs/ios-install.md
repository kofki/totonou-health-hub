# Installing Health Hub on your iPhone via Xcode

Ticket **P1-09**. The Expo app is prebuild-ready (`ios.bundleIdentifier` is set in
`mobile/app.json`), so you can generate a native Xcode project any time.

## One-time setup
1. Install Xcode from the App Store and open it once (accept the license, let it install
   iOS platform support).
2. Xcode → Settings → Accounts → add your Apple ID.
3. Plug in your iPhone. On the phone: trust the computer. Settings → Privacy & Security →
   Developer Mode → on (phone reboots).

## Build + install
```bash
cd mobile
npx expo prebuild --platform ios     # generates mobile/ios/ (gitignored)
open ios/HealthHub.xcworkspace       # opens Xcode
```
In Xcode:
1. Select the `HealthHub` target → Signing & Capabilities.
2. Check "Automatically manage signing", pick your Team (your Apple ID's Personal Team).
3. If the bundle id collides, change it (e.g. suffix your initials) — Personal Teams share a
   global namespace.
4. Select your iPhone as the run destination (top toolbar) and press ▶ Run.
5. First run: on the phone, Settings → General → VPN & Device Management → trust your
   developer certificate.

Day-to-day JS changes do NOT need Xcode — `npx expo start` hot-reloads over Wi-Fi into the
installed app. Xcode is only needed again when native config changes or the cert expires.

## Signing paths ("permanently on my phone")
| | Free Apple ID | Paid Apple Developer ($99/yr) |
|---|---|---|
| App validity | **7 days**, then re-run from Xcode | 1 year |
| Devices | 3 per bundle id | 100, plus TestFlight (90-day builds, no cable) |
| App name/icon on home screen | yes | yes |

With the free path, "permanent" means pressing ▶ Run once a week while the phone is plugged
in. If that gets old, the $99 account (or TestFlight via `eas build`) removes the expiry.

## Regenerating
`mobile/ios/` is gitignored and disposable. After changing `app.json` or adding native
modules: `npx expo prebuild --platform ios --clean` and rebuild in Xcode.

## Troubleshooting
- "Untrusted Developer" → trust cert in VPN & Device Management (step 5 above).
- Build fails after dependency changes → `cd ios && pod install` (CocoaPods), or prebuild `--clean`.
- Metro can't connect → phone and Mac must share the same Wi-Fi network.
