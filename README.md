# WorkingOut

Native iOS training app for strength training and running, developed by Dion.

## Current MVP
- Four tabs: Overview, Training, Progress and Profile.
- Timed strength and running sessions saved to Apple Health with user permission.
- HealthKit workout history across sources, including Garmin Connect imports where available.
- Workout duration, source, and distance/energy when supplied by HealthKit.
- WorkingOut dumbbell branding.

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
