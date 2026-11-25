# WorkingOut

Dion's native iPhone app for strength training and running. Available in Danish and English, with four tabs · Overview, Training, Progress, and Profile.

## Premium training interface

Overview prioritizes today's session and links each calendar day to planned and completed workouts. Training opens directly to programs and upcoming sessions with exercise media, previous performance, and load suggestions. Progress opens on All Time, remembers the selected period, and separates strength from running. Historic charts aggregate into calendar buckets and link records back to their source workouts. HealthKit refreshes the complete available strength and running history before the selected period is applied on screen.

CI captures Overview, Training, Strength Progress, and Running Progress from an isolated simulator fixture. The fixture is available only in debug simulator builds. See the simulator screenshot artifact on the CI run.

## Phase 3

| Area | Status and scope |
| --- | --- |
| Exercise library | Bundled 876 Free Exercise DB records, including 12 reviewed mappings onto existing IDs. Search accepts both languages when a translation exists. Four imported records have specific Danish instructions. Other imported text falls back to English. Seven verified RepDB illustrations can be loaded and cached. See [exercise data and licensing](docs/exercise-data.md). |
| Programs | Reusable programs support weekday training days, editable exercise ordering and set targets, warm-ups, per-exercise rest, repetition ranges, and load targets. Today's workout and the weekly plan support starting, skipping, rescheduling, and viewing completion. Original single-workout programs still open and can be converted to a training day. |
| Progression | WorkingOutKit tests double progression, missed targets, assisted load direction, bodyweight, incomplete work, manual selection and effort. Suggestions apply only after confirmation. Optional prefill uses a previously recorded load. |
| Apple Watch | WorkingOut guidance replaces the inherited Watch screens and complication appearance. The Watch caches plans and active sets, records local results before HealthKit and peer delivery, then retains an outbox until the phone durably acknowledges the result. Packaged state and idempotency tests run in CI. Paired-device checks for workout guidance, HealthKit recovery, transfers and complications remain open. |
| Garmin | Apple Health import remains supported. The internal structured workout draft and provider mapping are tested. Direct Training API access and device validation remain external dependencies. See [Garmin integration feasibility](docs/garmin-integration.md). |
| CI | Pull requests and manual dispatch run CI once per event. Core checks and simulator build can run in parallel. The simulator smoke test reuses the build-for-testing products. Dependencies are local Swift packages, and CI keeps build products within the runner to avoid large or stale cross-run caches. Phase 2's reference PR run took 22m09s and separately built before invoking the UI test. See the [Phase 3 PR](https://github.com/DionBP/WorkingOut/pull/4) for the measured run and release verification. |

## Phase 2 foundations

| Area | Status and scope |
| --- | --- |
| Language and display | Implemented. Persistent system, Danish, and English selections apply in app. Weight, distance, appearance, rest defaults and week start are independent preferences. Automated catalog coverage is available. The simulator smoke test covers language switching and relaunch. Wider Dynamic Type and VoiceOver checks remain open. |
| Dashboard | Implemented. Weekly goal and calendar, known duration and distance, strength volume, recent activity, heaviest lift, and workout shortcuts use the local log and Apple Health query results. |
| Strength | Implemented. The 105 built-in exercises have bilingual names, equipment and muscle metadata, and shared movement instructions. Custom exercises are editable. Logs support sets, warm-ups, previous sets, rest, notes, pause, recovery, and history editing. Exercise-specific illustrations and detailed setup instructions remain future work. |
| Programs | Implemented. Six localized templates and persistent user programs support editing, reordering, duplicating, deleting, rest settings, notes, target repetitions and starting workouts. Completed strength logs can be copied into a program. |
| Persistence and metrics | Verified with Linux Swift tests for additive JSON migration, workout recovery, program validation, units, splits, personal-record calculations, and reconciliation. Existing file and record IDs are retained. No SwiftData schema changes were needed. |
| Running | Implemented, awaiting physical-device verification. Core Location records locally, including background updates during an active run. MapKit displays routes, and the run screen shows GPS distance, current and average pace, splits, pause and recovery. GPS gaps begin a new segment. Distance remains unavailable until a valid measurement exists. |
| Apple Health and Garmin | Implemented, awaiting physical-device verification. Imports supported workout types, source, attached distance, energy, average heart rate and routes when available. Locally recorded activities optionally mirror to HealthKit and are reconciled by workout or sync ID. Legacy same-app logs use a narrow time match. Independent recordings from different sources may still appear separately. Direct Garmin is an external dependency. |
| Progress | Partially implemented. Preset and custom dates, native volume and distance charts, exercise weight and estimated 1RM progression, working sets by primary muscle, longest run, and GPS distance records are available. Side-by-side period comparisons remain future work. |
| Data export | Implemented. Profile exports completed local strength sessions, GPS runs, saved programs and custom exercises as a versioned JSON document. |
| iPhone widgets | Inherited iPhone widgets and Live Activities remain scheduled for replacement. |

The app uses the existing WorkingOut logo and native system symbols. Exercise illustration credits appear on the exercise detail screen. [Exercise data by RepDB (repdb.co)](https://repdb.co)

## Apple Health and Garmin

For Garmin imports, use Apple Health → profile → Apps under Privacy → Connect and enable Workouts. Sync the watch with Garmin Connect open, then refresh workouts in WorkingOut. Garmin's Apple Health transfer omits GPS routes and limits timed-activity heart rate to high and low values. Distance and energy are shown when attached to the workout. Record each session on one device to avoid parallel source records. Read permissions may result in an empty list without a sign-in or permission error. See [Garmin's Apple Health sharing guide](https://support.garmin.com/da-DK/?faq=lK5FPB9iPF5PXFkIpFlFPA).

Local training records and GPS routes stay on device. Apple Health writes use OS authorization, and deleting a strength log from WorkingOut hides its linked import locally. The existing Health entry is managed in Apple Health.

Foreground refresh is supported. For future background HealthKit updates, evaluate `HKObserverQuery` combined with persisted `HKAnchoredObjectQuery` anchors and a background delivery entitlement. Handle deletes, finish observer callbacks promptly, and test lock-state access and authorization changes before enabling it.

## Development and validation

- Use Xcode 27 and the iOS 27 SDK. The iPhone deployment target is iOS 17. Run `python3 scripts/generate_app_icons.py` and `xcodegen generate`, then open `WorkingOut.xcodeproj` and select `WorkingOut`.
- Run `swift test --package-path Packages/WorkingOutKit`, `swift test --package-path Packages/PadelKit`, and `python3 scripts/check_workingout_localization.py`.
- Linux runs package tests and static checks. Pull-request GitHub Actions builds the iOS and watchOS simulator targets with Xcode 27. CI runs a smoke test for live language switching and persistence when an iOS 27 iPhone simulator device is available. Run it locally with `xcodebuild test -project WorkingOut.xcodeproj -scheme WorkingOut -destination "platform=iOS Simulator,id=<simulator UUID>"`.
- On iPhone, verify language switching immediately and after relaunch, both unit settings across the same history, wide Dynamic Type, and light and dark appearances. Test migration from an existing build, rest notification delivery while locked, GPS pause, lock, signal loss, and restart, and HealthKit denial, connection, import and local round-trip. Test Garmin import using real supported activities.
- The local log keeps the original `workingout-gym-v1.json` filename. New fields are optional for backward decoding. Existing built-in exercise names map to immutable IDs. Other legacy names are preserved as custom exercises. An unreadable file blocks writes, and successful updates atomically replace the previous snapshot.

## Roadmap

1. Verify end-to-end on physical devices and refine exercise setup guidance, timer behavior, and analytics.
2. Add supported HealthKit background updates, source reconciliation controls, running records and time-range comparisons.
3. Verify Apple Watch offline delivery and workouts on paired devices, then replace inherited iPhone widgets and Live Activities.
4. Evaluate direct Garmin access and verify local export on device. See [Garmin integration feasibility](docs/garmin-integration.md).

Main deploys to TestFlight. The existing CI, signing identity verification and cleanup procedures are required. TestFlight revokes only new development certificates whose fingerprint matches a newly installed runner identity for the same team. See [legacy infrastructure reference](docs/legacy-padel-reference.md) and [development instructions](AGENTS.md).
