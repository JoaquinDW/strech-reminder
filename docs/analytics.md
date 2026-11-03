# PostHog analytics

Project **707520**, US Cloud: https://us.posthog.com/project/707520.
SDK: https://posthog.com/docs/libraries/ios.

`Config/PostHog.xcconfig` supplies the public ingestion token and host through build
settings expanded into `Config/Info.plist`. This is a public client token, not a
personal API key. Override `POSTHOG_PROJECT_TOKEN` / `POSTHOG_HOST` in build settings
or the running process environment to use another project. Run `xcodegen` after
changing `project.yml`; the SDK is an SPM dependency with a committed resolution.

Release builds collect events. Debug builds require the runtime environment variable
`POSTHOG_ENABLE_DEBUG=1` in Xcode's Run scheme. XCTest, previews and launches using
`-test*`, `-seed*` or `-resetData` never collect, even with debug enabled.
Events include `environment`: `production`, `testflight` or `debug`. Filter reports
to `production` (or explicitly include TestFlight while beta testing).

The SDK retains its generated anonymous installation ID across launches. There is no
login or `identify` call. Resetting local progress keeps this ID, so replaying
onboarding does not manufacture a new user. No focus/friction answers, work schedule,
name or email are sent. Screen/tap autocapture, replay and surveys are disabled.
The SDK supplies normal device/app metadata and queues offline events.

| Event | Trigger / properties |
| --- | --- |
| `Application Installed`, `Application Updated`, `Application Opened`, `Application Backgrounded` | SDK lifecycle events |
| `onboarding_started` | A new onboarding flow appears |
| `onboarding_step_viewed` | Initial step or navigation; `step_index` (0–7), `step_name` |
| `onboarding_skipped` | Skip button; `from_step` |
| `onboarding_completed` | Plan saved; `duration_minutes`, `daily_goal`, `reminders_enabled` |
| `notification_permission_requested` | Explicit action when authorization was undetermined |
| `notification_permission_result` | That request resolves; `granted` |
| `reminders_toggled` | Saved reminder preference changes; `enabled` |
| `reminder_opened` | Reminder body/start button; `action`: `open` / `start_break` |
| `reminder_snoozed` | Snooze action selected; `snooze_minutes` (10) |
| `break_started` | Movement starts, including the reminder start shortcut |
| `break_completed` | User confirms “Yes, I moved”; `routine_reached_end`, `is_first_break`, `breaks_today` |
| `break_abandoned` | Started break dismissed or declined; `reason`: `dismissed` / `not_confirmed` |
| `daily_goal_reached` | A confirmed break first reaches today's goal; `daily_goal` |
| `weekly_recap_viewed` | Weekly recap sheet opens; `minutes`, `breaks`, `is_current_week` |
| `weekly_recap_share_tapped` | Share button on the recap; `minutes`, `breaks` (not whether it was sent) |
| `app_error` | Persistence failure; operation, error domain/code only |

All three break events share `break_id`, `duration_minutes` (planned duration, not
measured movement), and `source` (`app` / `reminder`). A dismissed overview produces
no start or abandonment. Backgrounding pauses the session without declaring it
abandoned. A confirmed break emits one completion and never an abandonment.
`routine_reached_end` means the last move was reached, possibly using Next/Finish;
it does not prove the user exercised for the full planned duration. Force-quitting
does not reliably emit abandonment; derive overall drop-off from the funnel too.

## Initial reports

- Activation funnel: `Application Installed` → `onboarding_completed` →
  `break_started` → `break_completed`, unique users, 24-hour conversion window.
  Existing installs first seen after adding the SDK count as installs here too.
- Onboarding: ordered `onboarding_step_viewed` steps, filtered by `step_index`.
  Skip intentionally bypasses steps.
- Retention: first-ever `break_completed` → returning `break_completed`, daily,
  inspect day 1 and day 7. Compare `source` / `duration_minutes` as useful.
- Notifications: compare starts/completions with `source=reminder` vs `app`.
  `reminder_opened` records interactions, not delivery or impressions.

For manual verification, opt into debug capture, use a normal launch without test
arguments, complete onboarding and a short break, and wait about 30 seconds for the
SDK batch. Check Live Events in the project for `environment=debug`. Never use a
personal API key in the iOS app.
