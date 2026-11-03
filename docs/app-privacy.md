# App Store privacy answers

What to enter in App Store Connect → App Privacy. Keep it in sync with
`Unshrimp/Resources/PrivacyInfo.xcprivacy`, `website/privacy.html` and
[analytics](analytics.md). PostHog and RevenueCat ship their own privacy manifests;
Xcode merges them into the archive's privacy report (Organizer → Generate Privacy Report).

- Privacy Policy URL: https://unshrimp.vercel.app/privacy.html
- Do you or your third-party partners collect data from this app? **Yes**
- Tracking (ATT): **No**. No advertising SDKs, no IDFA, no data broker sharing.

| Data type | Source | Purpose | Linked to identity | Used for tracking |
| --- | --- | --- | --- | --- |
| Usage Data → Product Interaction | PostHog events (onboarding, reminders, breaks, goals) | Analytics | No | No |
| Usage Data → Other Usage Data | PostHog lifecycle events (installed, opened, backgrounded) | Analytics | No | No |
| Diagnostics → Other Diagnostic Data | PostHog `app_error` (error domain/code only) | App Functionality | No | No |
| Purchases → Purchase History | RevenueCat subscription status and receipts | App Functionality | No | No |

"Not linked" holds because there is no account, `identify` call or RevenueCat
`logIn`: both SDKs use generated anonymous IDs. If a login or identify call is ever
added, change these to **Linked to you** and update the manifest and policy.

Not collected: contact info, health and fitness, location, contacts, user content,
browsing or search history, sensitive info, financial info (Apple handles payment).
Break history, schedule and focus areas stay on the device.

## Review notes

Suggested text for App Review Information → Notes:

> Unshrimp has no account. It uses PostHog for anonymous usage analytics and
> RevenueCat to manage the auto-renewable subscriptions (yearly and monthly, 3-day
> trial). Reminders are local notifications. The paywall appears after onboarding;
> sandbox purchases unlock the app.
