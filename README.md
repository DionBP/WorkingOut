# WorkingOut

Dion's native iPhone app for strength training and running. Available in Danish and English, with four tabs · Overview, Training, Progress, and Profile.

## Phase 2 status

| Area | Status and scope |
| --- | --- |
| Language and display | Implemented. Persistent system, Danish, and English selections apply in app. Weight, distance, appearance, rest defaults and week start are independent preferences. Automated catalog coverage is available. Language switching, text fit and accessibility still need simulator or device checks. |
| Dashboard | Implemented. Weekly goal and calendar, known duration and distance, strength volume, recent activity, heaviest lift, and workout shortcuts use the local log and Apple Health query results. |
| Strength | Implemented. The 105 built-in exercises have bilingual names, equipment and muscle metadata, and shared movement instructions. Custom exercises are editable. Logs support sets, warm-ups, previous sets, rest, notes, pause, recovery, and history editing. Exercise-specific illustrations and detailed setup instructions remain future work. |
| Programs | Implemented. Six localized templates and persistent user programs support editing, reordering, duplicating, deleting, rest settings, notes, target repetitions and starting workouts. Completed strength logs can be copied into a program. |
| Persistence and metrics | Verified with Linux Swift tests for additive JSON migration, workout recovery, program validation, units, splits, personal-record calculations, and reconciliation. Existing file and record IDs are retained. No SwiftData schema changes were needed. |
| Running | Implemented, awaiting physical-device verification. Core Location records locally, including background updates during an active run. MapKit displays routes, and the run screen shows GPS distance, current and average pace, splits, pause and recovery. GPS gaps begin a new segment. Distance remains unavailable until a valid measurement exists. |
| Apple Health and Garmin | Implemented, awaiting physical-device verification. Imports supported workout types, source, attached distance, energy, average heart rate and routes when available. Locally recorded activities optionally mirror to HealthKit and are reconciled by workout or sync ID. Legacy same-app logs use a narrow time match. Independent recordings from different sources may still appear separately. Direct Garmin is an external dependency. |
| Progress | Partially implemented. Preset and custom dates, native volume and distance charts, exercise weight and estimated 1RM progression, working sets by primary muscle, longest run, and GPS distance records are available. Side-by-side period comparisons remain future work. |
| Watch, widgets and export | Deferred. Inherited Watch and widget features still use Padel screens. Dedicated Watch training sessions, WorkingOut widgets and Live Activities, and data export remain future work. |

No third-party exercise illustrations are included. The app uses its existing WorkingOut logo and native system symbols.

## Apple Health and Garmin

For Garmin imports, use Apple Health → profile → Apps under Privacy → Connect and enable Workouts. Sync the watch with Garmin Connect open, then refresh workouts in WorkingOut. Garmin's Apple Health transfer omits GPS routes and limits timed-activity heart rate to high and low values. Distance and energy are shown when attached to the workout. Record each session on one device to avoid parallel source records. Read permissions may result in an empty list without a sign-in or permission error. See [Garmin's Apple Health sharing guide](https://support.garmin.com/da-DK/?faq=lK5FPB9iPF5PXFkIpFlFPA).

Local training records and GPS routes stay on device. Apple Health writes use OS authorization, and deleting a strength log from WorkingOut hides its linked import locally. The existing Health entry is managed in Apple Health.

Foreground refresh is supported. For future background HealthKit updates, evaluate `HKObserverQuery` combined with persisted `HKAnchoredObjectQuery` anchors and a background delivery entitlement. Handle deletes, finish observer callbacks promptly, and test lock-state access and authorization changes before enabling it.

## Development and validation

- Use Xcode 27 and the iOS 27 SDK. The iPhone deployment target is iOS 17. Run `python3 scripts/generate_app_icons.py` and `xcodegen generate`, then open `Padel.xcodeproj` and select `PadelApp`. Inherited naming is required by the existing automation.
- Run `swift test --package-path Packages/WorkingOutKit`, `swift test --package-path Packages/PadelKit`, and `python3 scripts/check_workingout_localization.py`.
- Linux runs package tests and static checks. Branch GitHub Actions builds the iOS and watchOS simulator targets with Xcode 27. CI runs a smoke test for live language switching and persistence when an iOS 27 iPhone simulator device is available. Run it locally with `xcodebuild test -project Padel.xcodeproj -scheme PadelApp -destination "platform=iOS Simulator,id=<simulator UUID>"`.
- On iPhone, verify language switching immediately and after relaunch, both unit settings across the same history, wide Dynamic Type, and light and dark appearances. Test migration from an existing build, rest notification delivery while locked, GPS pause, lock, signal loss, and restart, and HealthKit denial, connection, import and local round-trip. Test Garmin import using real supported activities.
- The local log keeps the original `workingout-gym-v1.json` filename. New fields are optional for backward decoding. Existing built-in exercise names map to immutable IDs. Other legacy names are preserved as custom exercises. An unreadable file blocks writes, and successful updates atomically replace the previous snapshot.

## Roadmap

1. Verify end-to-end on physical devices and refine exercise setup guidance, timer behavior, and analytics.
2. Add supported HealthKit background updates, source reconciliation controls, running records and time-range comparisons.
3. Build the native WorkingOut Watch workout experience and replace inherited widgets and Live Activities as their equivalents become ready.
4. Add user-controlled export and evaluate direct Garmin access. See [Garmin integration feasibility](docs/garmin-integration.md).

Main deploys to TestFlight. The existing CI, signing identity verification and cleanup procedures are required. TestFlight revokes only new development certificates whose fingerprint matches a newly installed runner identity for the same team. See [legacy infrastructure reference](docs/legacy-padel-reference.md) and [development instructions](AGENTS.md).
