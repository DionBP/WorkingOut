# WorkingOut

Native iOS training app for strength training and running, developed by Dion.

## Current MVP
- Four tabs: Overview, Training, Progress and Profile.
- Timed strength and running sessions saved to Apple Health with user permission.
- HealthKit workout history across sources, including Garmin Connect imports where available.
- Workout duration, source, and distance/energy when supplied by HealthKit.
- WorkingOut dumbbell branding.

## Strength logging
- Searchable 30-exercise library, custom exercises, Push/Pull/Legs and Full Body templates.
- Editable sets, kg, reps, completion, previous set prefills, heaviest logged weight and in-app rest countdown.
- Local strength history and volume chart, weekly workout goal, imported running pace when distance is available.
- Local strength logs are stored on-device, separately from HealthKit; no cross-device sync or automatic Garmin set matching yet.

## Garmin
Pair and sync the watch with Garmin Connect on iPhone. Enable Apple Health sharing for workouts and available metrics in Garmin Connect / Apple Health. Open Garmin Connect after a workout and refresh WorkingOut. Imported data varies by device and permissions. Direct Garmin API, routes, detailed sets/reps, live GPS and live heart rate are not implemented. Avoid recording the same workout twice.

## Development
Dion is the developer. Existing Padel-named targets and package remain temporarily to preserve the working signing and TestFlight pipeline. Apple Watch training UI and legacy widgets still require migration. See [legacy infrastructure reference](docs/legacy-padel-reference.md) for inherited setup details, not current product features.

- Xcode 27, iOS 27 SDK, iOS deployment target 17.
- Run `python3 scripts/generate_app_icons.py` and `xcodegen generate`.
- Open `Padel.xcodeproj` and select the PadelApp scheme.
- GitHub Actions runs CI on feature branches and deploys main to TestFlight.
- Keep credentials in GitHub Actions secrets; never commit them.
- HealthKit permissions and Garmin sync must be tested on a physical iPhone.

## Roadmap
Exercise library, sets/reps/weight, training plans, running GPS and pace, charts, Apple Watch workout recording, and evaluation of direct Garmin integration.

### CI signing cleanup
TestFlight snapshots Apple certificate IDs and runner signing identities before the build. After success or failure it revokes only new development certificates whose fingerprint matches a newly installed local signing identity for the same team. It never revokes distribution or pre-existing certificates. If ownership cannot be established, certificates are left untouched. Hard runner termination can prevent cleanup; inspect the Apple portal if necessary. Existing API credentials are reused; no extra secrets are required.

### WorkingOutKit
Shared Swift package for training calculations: volume, heaviest completed weight, estimated 1RM, running pace and weekly goal progress. Run `swift test --package-path Packages/WorkingOutKit` locally. CI runs these tests alongside legacy PadelKit tests until the old Watch and widget code is migrated. Estimated 1RM is available in the core but not yet displayed in the app.
