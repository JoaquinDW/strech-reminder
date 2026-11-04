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
- `-testStand` opens a quick stand; `-testPaywall` forces the paywall in debug builds; `-skipPaywall` skips it (UI tests use it).
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

- Every confirmed break earns energy (+10), each quick stand +3 (up to 30 a day), with bonuses for the first break, spreading
  breaks out (60+ minutes apart), returning after a couple of days away, and reaching
  the daily goal.
- Energy totals unlock desk decor: sprout, mug, lamp, poster, fairy lights, snail.
  The next item shows as a faint silhouette in the scene. Nothing is ever taken away.
- Each day the goal is met moves Kip one stop along the weekly Tide Pool Trail.

### Reminders

Two kinds of reminder, scheduled locally inside working days and hours:

- **Breaks** every chosen interval (45 min to 2 h), with "Stretch with Kip now" and "In 10 minutes" actions.
- **Quick stands** (on by default, every 30, 45 or 60 min) in between: one standing move of 20 to 60
  seconds, named in the reminder, with "Done, I stood up" and "Not now" actions that work without opening
  the app, plus "Show me" for a one-move screen. Never within 15 minutes of a break reminder. After three
  stands skipped or ignored in a row, the next one comes 30 minutes later with a lighter line.
- A **weekly recap** reminder an hour before the end of the last workday of the week.

Slots that land soon after a break or stand are skipped. With stands on, the plan covers 4 days (7 without),
under iOS's 64 pending-notification limit; it's rebuilt on every preference change, break, stand, and when the
app becomes active. Permission is only requested after the user taps "Turn on reminders"; if denied, the app
keeps working and Settings links to iOS notification settings.

### How it feels

- A break ends with "How does your body feel?": Looser, Same or Something bothered me (all count as a break),
  or "I didn't get to it". "Something bothered me" asks which move, and that move sits out of routines for
  two weeks. Breaks of 3 minutes or more always include one standing move.
- Onboarding asks for an optional 0 to 10 stiffness score per focus area; a weekly check-in card on Home asks
  again. The weekly recap shows quick stands, how many breaks left you looser, and each area's stiffness from
  the first check-in to the latest (kept out of the shareable image).

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
