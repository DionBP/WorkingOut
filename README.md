# Padel

A native iOS + Apple Watch app for scoring padel matches, with a built-in
Americano tournament mode. Score a whole match from your wrist, run an
Americano evening with automatic partner rotation, and ship builds straight
to TestFlight via GitHub Actions.

## Features

- **Real padel scoring** — points (0/15/30/40), deuce & advantage or
  "golden point" sudden death, games, sets, tiebreaks (regular and
  10-point match tiebreak for the decider), configurable best-of-1/best-of-3.
- **Apple Watch scoring** — score a full match entirely on the Watch:
  big tap zones, swipe right or use the compact undo button to take back a
  point, and get haptic feedback on every point and on match win. Works
  standalone (no phone nearby needed) and
  live-syncs to the iPhone app over WatchConnectivity when it's around.
- **Americano mode** — set up a group of players (4, 8, 12, 16…), auto-generate
  a round schedule that rotates partners/opponents to minimise repeats, score
  each court's race-to-N points, and see a live individual leaderboard as
  points accumulate across rounds. Fully playable from the Watch. When the
  player count doesn't fill the courts, sit-outs rotate fairly and the app
  shows who's resting each round.
- **Mexicano mode** — the other tournament format the padel world plays:
  every round is re-drawn from the live standings (1st + 4th vs 2nd + 3rd in
  each group of four) so games get more even as the evening progresses.
  Rounds appear one at a time as courts finish. Works on iPhone and Watch,
  and both devices derive the next round deterministically so they can never
  disagree about the draw.
- **Match history & player stats** — every match and Americano session is
  saved; the Players tab shows each saved player's win rate and an Elo-style
  rating, and tapping a player opens head-to-head records and per-partner
  chemistry computed across matches *and* Americano rounds.
- **Shareable standings** — export the live or final Americano/Mexicano
  leaderboard as an image straight into the group chat.
- **Serve indicator** — shows which team *and which of the two partners* is
  serving, based on real padel serve rotation rules.
- **Watch workout tracking** — scoring on the Watch runs a HealthKit workout
  session alongside: live heart rate on the scoreboard, active calories, and
  a workout saved to the Health app (recorded as tennis — HealthKit has no
  padel type). The session also keeps the app alive for the whole match so
  watchOS never suspends it mid-set. Requires the one-time Apple setup below;
  without it (or if the user declines Health access) scoring works unchanged.
- **Live Activity** — while a match is scored on the iPhone (including points
  relayed live from the Watch), the score lives on the lock screen and in the
  Dynamic Island.
- **Watch-face complication** — add the Padel complication to any watch face
  (circular, rectangular, corner or inline) and one tap jumps straight into the
  scoreboard: it resumes the match in progress, or starts a fresh quick match,
  ready to register points without opening the app first.
- **Player profiles** — save players once, quick-add them into new matches or
  Americano sessions, colour-coded avatars.

## Architecture

```
Padel/
├── Packages/PadelKit/        Swift package: all scoring/tournament logic
│   ├── Sources/PadelKit/     Player, Team, MatchEngine, AmericanoScheduler…
│   └── Tests/PadelKitTests/  XCTest unit tests for the scoring engine
├── iOS/PadelApp/             SwiftUI iOS app (SwiftData persistence)
├── WatchApp/PadelWatch/      SwiftUI watchOS app (standalone-capable)
├── project.yml               XcodeGen spec — generates Padel.xcodeproj
├── fastlane/                 Fastfile/Appfile for the TestFlight lane
└── .github/workflows/        CI: unit tests + TestFlight deploy
```

**PadelKit** is the single source of truth for all rules. Both apps depend on
it as a local Swift package, so the iPhone and the Watch can never disagree
about what a score means. Scoring state is stored as an *append-only log of
point winners* (`pointLog: [TeamSide]`); the visible score (games, sets,
deuce/advantage, tiebreak, winner) is always re-derived from that log by a
pure function (`MatchEngine.simulate`). That makes "undo" trivial and
correct (drop the last log entry) and makes syncing between devices safe —
whichever device has the longer log wins, no merge logic needed.

The project has **no physical `.xcodeproj` committed** — CI generates it from
`project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) on every
build.

## Deploying to TestFlight (Windows + GitHub)

This repository uses **GitHub Actions + Xcode automatic/cloud-managed signing**. You can set up TestFlight from Windows without a local Mac, a `.p12` export, a distribution-certificate password, provisioning-profile files, or Fastlane Match.

The complete deploy configuration is kept together in **[GitHub Settings → Secrets and variables → Actions](https://github.com/DionBP/WorkingOut/settings/secrets/actions)**. Choose the **Secrets** tab for private credentials or **Variables** for non-sensitive app configuration.

**Repository owner/admin action:** GitHub repository Secrets and Variables require administrative access. A collaborator with only write access may prepare this workflow and PR, but the repository owner/admin must enter the values under Settings.

### Step 1 — Obtain the Apple API key

Open [App Store Connect → Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api) and select **App Store Connect API → Team Keys**. Use an active Team API key with sufficient rights to manage signing and upload builds (Admin is the simplest role for initial setup).

Download the `.p8` file immediately after creation. **Apple lets you download the private key only once.** Never commit it or paste it into an online converter.

### Step 2 — Create exactly three repository Secrets

Select **Secrets → New repository secret** in GitHub.

| Secret name | Where to copy it from | Example / format |
|---|---|---|
| `APP_STORE_CONNECT_KEY_ID` | **Key ID**, beside the Team Key in App Store Connect | `2X9R4HXF34` — normally 10 uppercase letters/digits |
| `APP_STORE_CONNECT_ISSUER_ID` | **Issuer ID** on App Store Connect's API Integrations page | `57246542-96fe-1a63-e053-0824d011072a` — UUID, 36 characters including four hyphens |
| `APP_STORE_CONNECT_API_KEY_P8_CONTENT` | The **complete, original text** of `AuthKey_<KEY_ID>.p8`; no conversion | Multiline text with `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` |

The Apple `.p8` file looks like this (incomplete example only):

```text
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBH...
-----END PRIVATE KEY-----
```

**Keep both BEGIN and END lines and all content in between.** You can copy the complete text from the original file using a text viewer on your **iPhone or Windows computer**. GitHub supports multiline Secrets directly; **no Base64 conversion is necessary**.

Open [WorkingOut → GitHub repository Secrets](https://github.com/DionBP/WorkingOut/settings/secrets/actions) and create `APP_STORE_CONNECT_API_KEY_P8_CONTENT`. Paste the **complete raw key text** into the value field and press **Add secret**. Never use the abbreviated example from this README.

Apple only allows one download of each `.p8` private key. If your file is lost, create a replacement Team API key and update the associated `APP_STORE_CONNECT_KEY_ID` too. Do not commit or upload private-key contents to a website or chat. Base64 provides no secrecy and is not needed.

### Step 3 — Create seven repository Variables

Open [GitHub Settings → Secrets and variables → Actions](https://github.com/DionBP/WorkingOut/settings/variables/actions) and choose **Variables → New repository variable**.

| Variable | What to enter |
|---|---|
| `APPLE_TEAM_ID` | Your Apple Developer **Team ID**, 10 characters, from the Apple Developer account's Membership details |
| `APP_DISPLAY_NAME` | The name that should appear under the app icon (for example `WorkingOut`) |
| `APP_BUNDLE_IDENTIFIER` | The **main iPhone app's** registered bundle ID |
| `WATCH_APP_BUNDLE_IDENTIFIER` | The registered Watch app bundle ID |
| `WIDGET_BUNDLE_IDENTIFIER` | The registered iOS widget extension bundle ID |
| `WATCH_WIDGET_BUNDLE_IDENTIFIER` | The registered Watch widget extension bundle ID |
| `ICLOUD_CONTAINER_IDENTIFIER` | The iCloud/CloudKit container identifier associated with the app |

**Important for this copied repository:** as checked when adding this deployment setup, `project.yml` and the local fallback `Config/App.xcconfig` still refer to Padel and `com.worsa.padel`. These are **not confirmed WorkingOut identities**. Do not copy them blindly to the seven Variables. Use the actual Team ID, display name, Bundle IDs and iCloud container that belong to the intended app/Apple team. This PR changes deployment wiring, not the app's UI or Swift source code.

For TestFlight, the **seven GitHub Variables override the local values**. For local simulator builds without repository variables, `Config/App.xcconfig` retains the project's existing defaults.

### Step 4 — Register/check the matching Apple identifiers

In the [Apple Developer identifiers portal](https://developer.apple.com/account/resources/identifiers/list), verify that the iPhone app, Watch app and both widget extensions have **explicit App IDs** matching the four corresponding GitHub Variables.

The main app must have an [App Store Connect app record](https://appstoreconnect.apple.com/apps) with the same `APP_BUNDLE_IDENTIFIER`.

This codebase currently declares **HealthKit** for the iPhone and Watch targets and **iCloud/CloudKit** for the iPhone target. Enable the corresponding capabilities for the correct identifiers, and check that the `ICLOUD_CONTAINER_IDENTIFIER` belongs to the right team and app. These must match the source code's entitlements.

### Step 5 — Run and verify the deployment

Open **[Actions → Deploy to TestFlight](https://github.com/DionBP/WorkingOut/actions/workflows/testflight.yml)** and choose **Run workflow → main → Run workflow** after the pull request has been merged and all ten values are set.

The workflow:
1. Runs the PadelKit Swift unit tests (the package is still named PadelKit in this copied codebase).
2. Verifies all **3 Secrets + 7 Variables** are present, and checks the Key ID and Issuer ID formats.
3. Generates Xcode project and icons, then writes the complete raw private `.p8` content to a temporary file and validates it on the ephemeral macOS runner.
4. Uses `-allowProvisioningUpdates` and App Store Connect API authentication for automatic signing/provisioning.
5. Builds the iOS+Watch archive and uploads it to TestFlight.
6. Deletes the temporary API key file even if the build fails.

The workflow can also run automatically on pushes to `main`. A successful GitHub job means upload finished; App Store Connect still needs to process the build before testers can install it.

**No longer used**: `MATCH_PASSWORD`, `APP_STORE_CONNECT_KEY_CONTENT`, `APP_STORE_CONNECT_API_KEY_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`, or `APPLE_TEAM_ID` as a *secret*. Old secrets can be removed once a new deployment has been verified.

## Local development (optional)

The app can also be run locally in Xcode 26+ on a Mac — this is never
required for deploying:

```bash
brew install xcodegen
xcodegen generate
open Padel.xcodeproj
```

Pick the **PadelApp** scheme to run on an iPhone (or Simulator with a paired
Watch Simulator), or the **PadelWatch** scheme to run the Watch app on its own.

The scoring-engine unit tests run anywhere Swift does, no Xcode project
needed:

```bash
cd Packages/PadelKit
swift test
```

## Changing bundle identifiers / team

The source project is still Padel, despite the repository being named WorkingOut. The GitHub **Variables** above are the single source of truth **for CI/TestFlight**. The corresponding values in `Config/App.xcconfig` are fallback defaults for local Mac builds.

If this repository is becoming a distinct WorkingOut app, configure the seven Variables and matching Apple registrations first. Separately rename the Xcode project/scheme, product name, source text and local fallback values if you want the application itself to become WorkingOut. The deployment change intentionally does **not** rename Swift targets or alter app functionality.

Keep the `APP_STORE_CONNECT_API_KEY_P8_CONTENT` private and use a new Team API key if the application belongs to a different Apple Developer team.

## Notes on the Americano scheduler

The schedule generator (`AmericanoScheduler.generateSchedule`) is a greedy
heuristic, not a full combinatorial optimiser: each round it shuffles the
player pool and, for every group of four, picks whichever of the three
possible partner splits has been used least often so far. Over several
rounds this gives a good spread of partners without needing precomputed
"social golfer problem" tables, and it degrades gracefully for odd player
counts (sit-outs rotate so whoever has rested the least rests next).

Mexicano rounds can't be scheduled up front — each draw depends on the
standings — so they're generated one at a time by
`AmericanoScheduler.nextRound(for:)` when every court in the current round
has finished. That generation is *deterministic*: it's seeded from the
session id and round index (`SeededRandomNumberGenerator`, SplitMix64),
including the new round's UUIDs, so the iPhone and the Watch independently
compute byte-identical rounds and WatchConnectivity sync converges without
any merge logic.

## What's intentionally out of scope

- iPad-specific layouts (the app is iPhone + Watch only, `TARGETED_DEVICE_FAMILY: "1"`)
- iCloud/CloudKit sync across a user's own multiple devices (Watch↔iPhone
  sync is handled directly over WatchConnectivity instead)
- A live score *on* the watch-face complication itself (it's a launcher into
  the scoreboard — showing the running score on the face would need an App
  Group to share state across processes)
