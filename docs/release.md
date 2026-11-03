# Release configuration

- App Store Connect: Unshrimp: Stretch Reminder, Apple ID `6830175290`.
- Bundle ID: `app.unshrimp.prototype`. This is the registered app's existing ID;
  changing it would target a different app.
- Apple Developer team: `F7RT2PJH7G`, read from the installed signing certificate.
- Version: `1.0.0` (matches the editable App Store version), build `2` (build `1`
  already exists in App Store Connect).
- Source of Xcode settings: `project.yml`; regenerate with `xcodegen generate`.

## Subscriptions

RevenueCat project: https://app.revenuecat.com/projects/38b988f3/overview
App configuration: `app61ecf39047`, bundle ID `app.unshrimp.prototype`.
The app ships only the public Apple SDK key, never an Apple `.p8` or RevenueCat
secret API key. Apple credentials already held by RevenueCat are reused.

| Reference name | Actual App Store product ID | Duration | US price | Trial |
| --- | --- | --- | --- | --- |
| `unshrimp_pro_yearly` | `com.balthasardeweert.unshrimp.pro.yearly` | 1 year | USD 29.99 | 3 days |
| `unshrimp_pro_monthly` | `com.balthasardeweert.unshrimp.pro.monthly` | 1 month | USD 6.99 | 3 days |

Both products belong to Apple's subscription group `22541668` (Unshrimp Pro),
at the same service level. The reference names are not the product IDs.
RevenueCat must map both products to entitlement `pro` and to the current offering's
`$rc_annual` and `$rc_monthly` packages. Prices and trial eligibility come from the
store. Unknown trial eligibility does not display a guaranteed free trial.

Configured on 3 November 2026: entitlement `pro` (`entle2b4eda595`) includes both
imported Apple products; offering `default` (`ofrngee10c9b887`) is the default and
contains both standard packages. Both Apple credential checks show valid in RevenueCat.

Validation: Debug simulator build and 27 unit tests passed. The simulator paywall
loaded the live offering and displayed USD 29.99/year with a 3-day trial and 64%
annual savings. The signed Release archive and App Store `.ipa` export succeeded.
Artifacts are in `build/Unshrimp-1.0.0-2.xcarchive` and `build/AppStore/Unshrimp.ipa`.
This work did not upload a new build or submit the app to review.

Before submission, verify a sandbox purchase, cancellation, restore and entitlement
activation on a signed device/TestFlight build. A successful archive or a populated
paywall does not prove the purchase flow works. The first subscriptions need Apple's
review together with the app. App privacy disclosures and review notes must reflect
PostHog usage analytics and RevenueCat subscriptions.

## Archive with full Xcode

`xcode-select` may still point to Command Line Tools. Use `DEVELOPER_DIR` to select
full Xcode for a command without requiring an administrator password:

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Unshrimp.xcodeproj -scheme Unshrimp -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Unshrimp-1.0.0-2.xcarchive \
  -allowProvisioningUpdates archive
```

To change the global selection, run `sudo xcode-select -s /Applications/Xcode.app`
in your own terminal. The password cannot be supplied by this agent.

## Public URLs

- Marketing: https://unshrimp.vercel.app/
- Support: https://unshrimp.vercel.app/support.html
- Privacy: https://unshrimp.vercel.app/privacy.html
- Terms: Apple's standard EULA, linked in `Billing.termsURL`.

Vercel's Root Directory must be `website`, with production branch `main`.
The previous production deployment used `main` commit `b2df147` but the repository
root, so it returned `NOT_FOUND` despite containing `website/`.
See `website/README.md` for deployment details. The updated privacy policy describes
the app's actual analytics and subscription providers.
