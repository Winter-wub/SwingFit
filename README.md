# SwingFit

SwingFit is a standalone Apple Watch and companion iPhone app for pickleball players. It automatically tracks match activity, detects swings, and turns post-game data into actionable coaching insights.

## Highlights

- **Zero-friction match tracking** — record an Apple Health workout while you play, without interacting with the screen.
- **Automatic swing analysis** — classify forehands, backhands, dinks, and smashes using Apple Watch motion sensors.
- **Post-match coaching** — review shot distribution, intensity trends, and personalized recommendations on iPhone.
- **Fast local sync** — transfer match data between Apple Watch and iPhone through WatchConnectivity.
- **Native Apple integration** — built with SwiftUI, SwiftData, CloudKit, HealthKit, CoreMotion, and CoreML.

## Requirements

- iOS 17 or later
- watchOS 10 or later
- Apple Watch worn on the hitting hand for accurate motion mapping

## Project structure

- `SwingFit/` — iPhone app
- `SwingFitWatch/` — Apple Watch app
- `Shared/` — shared models and services
- `Tests/` — unit tests

## Development

Open `SwingFit.xcodeproj` in Xcode, select an iPhone and paired Apple Watch destination, then build and run.

### Local OpenRouter configuration

AI coach summaries are optional in local development. To enable them:

1. Revoke any previously exposed key, then copy `.env.example` to an untracked `.env` file.
2. Set `OPENROUTER_API_KEY` in `.env`.
3. Run `./Scripts/generate-secrets-xcconfig.sh` before opening or building the project.

The generated `Config/Secrets.xcconfig` and `.env` are ignored by Git. Do not commit either file or a real key. Release builds deliberately omit this configuration. Since a value embedded in an iOS debug app can still be extracted, use this workflow for local development only—not for a production secret.

## Product principles

1. Play without needing to look at or tap the Watch.
2. Convert motion data into clear, useful coaching advice.
3. Keep Watch-to-iPhone sync seamless.
4. Preserve a native Apple Fitness and Health experience.
