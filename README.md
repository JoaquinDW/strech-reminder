# Unshrimp (working name)

A playful iPhone companion for short movement breaks during long desk days.
Kip the shrimp gets absorbed in work too, looks up when it's time to move,
guides a short break, and grows a little desk world as you stay consistent.

> Prototype. Exercise content is clearly marked demo/placeholder material and
> must be replaced with professionally reviewed guidance before release. The app
> frames breaks around movement and feeling refreshed; it makes no medical claims.

## Run it

Requirements: Xcode 16 or newer (built with Xcode 26), iOS 18+ simulator or device,
and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen   # once
xcodegen                # generates Unshrimp.xcodeproj from project.yml
open Unshrimp.xcodeproj
```

Useful launch arguments (Edit Scheme → Run → Arguments):

- `-resetData` starts fresh (onboarding again).
- `-seedWeek` fills earlier days of the current week with sample breaks.
- `-testPaywall` forces the paywall in debug builds; `-skipPaywall` skips it (UI tests use it).
- Debug-only media previews: `-testTraining`, optionally `-testReduceMotion` or
  `-testLargeType`. These open a deterministic routine without resetting saved data.

## Structure

PostHog tracks onboarding, reminder interactions and confirmed breaks. Configuration,
event definitions and initial reports: [analytics notes](docs/analytics.md).
Debug/test launches do not send events unless explicitly enabled for manual testing.

| Folder | What lives there |
| --- | --- |
| `Unshrimp/Brand` | App and mascot names, so branding is a one-file change |
| `Unshrimp/Design` | Design tokens (`Theme.swift`), buttons, chips, cards, shared preference controls |
| `Unshrimp/Mascot` | The vector shrimp rig, poses and motion, desk scene, unlockable item art, confetti |
| `Unshrimp/Model` | Persistence, app state, energy and unlock rules, reminder planning, notifications, demo routines |
| `Unshrimp/Features` | Onboarding, Home, guided break + reward, settings |

### Mascot rig

`ShrimpRenderer` draws Kip from a chain of overlapping circles along a bendable spine.
A `ShrimpPose` is a handful of numbers (heading, curl, head tilt, arm angles, eyes,
mouth, antenna sway…), and `ShrimpMotion` maps each `ShrimpState`
(`working`, `inviting`, `stretching`, `celebrating`, `resting`, `exercise(…)`) plus
time to a pose. State changes blend smoothly. Animation runs in a `TimelineView` that
pauses offscreen, in the background, and when Reduce Motion is on (Kip then holds a
calm key pose).

### Exercise demonstrations

Six selected illustrated instructor clips play locally during onboarding and guided
breaks. Kip stays beside the instructor and offers occasional comments. Preparation
and side changes have separate countdowns; pausing or backgrounding freezes both the
session and the video. Reduce Motion replaces playback with three selectable poses.

The 2/3/5-minute routines use four/six/eight steps from the selected media. Longer
routines revisit two moves, explicitly marked in the overview. Movement time matches
the chosen duration; preparation adds a few seconds. The four unfinished exercises
are excluded from automatic routines.

See [media integration notes](docs/exercise-media-integration.md) for asset choices,
remaining content limitations, and simulator verification. Session unit tests are in
`UnshrimpTests`; media and full-path UI tests are in `UnshrimpUITests`.

### Rewards

- Every confirmed break earns energy (+10), with bonuses for the first break, spreading
  breaks out (60+ minutes apart), returning after a couple of days away, and reaching
  the daily goal.
- Energy totals unlock desk decor: sprout, mug, lamp, poster, fairy lights, snail.
  The next item shows as a faint silhouette in the scene. Nothing is ever taken away.
- Each day the goal is met moves Kip one stop along the weekly Tide Pool Trail.

### Reminders

Local notifications are scheduled for the next 7 days inside working days and hours
(max 60 pending), skipping slots that fall soon after a break you already took. They're
rescheduled on every preference change, after each break, and when the app becomes
active. Notifications offer "Start a break" and "In 15 minutes" actions. Permission is
only requested after the user taps "Turn on reminders"; if denied, the app keeps working
and Settings links to iOS notification settings.

## Subscriptions

Unshrimp has a hard paywall right after onboarding: a free trial, then yearly or monthly,
through [RevenueCat](https://www.revenuecat.com) (`Model/Subscription.swift`, `Features/Paywall`).
Prices and the trial length are read from the App Store, so they change in App Store Connect
without a new build. Reminders are only scheduled while the `pro` entitlement is active.

The production App Store public SDK key is configured in `Billing.revenueCatAPIKey`.
The existing App Store Connect products are `com.balthasardeweert.unshrimp.pro.yearly`
and `com.balthasardeweert.unshrimp.pro.monthly`. Both must unlock the `pro` entitlement
in RevenueCat and be attached to the current offering's annual and monthly packages.
Use `-skipPaywall` for development without purchasing and `-testPaywall` to verify the store.

See [release configuration](docs/release.md) for signing, archiving and website deployment.
