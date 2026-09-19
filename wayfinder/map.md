## Destination

An iOS and standalone Apple Watch app for Pickleball that records health metrics (Apple Health), analyzes swings (Forehand/Backhand/Speed via CoreMotion), and includes a manual scorekeeper. 

## Notes

- Domain: iOS (SwiftUI, HealthKit, CoreMotion, WatchConnectivity, CoreData/SwiftData)
- Requires standalone Watch app capable of saving Pickleball Workouts to Apple Health.

## Decisions so far

- [Ticket 1: Sync mechanism](tickets/1-sync-mechanism.md): Use CloudKit + SwiftData for automatic syncing via iCloud.
- [Ticket 2: Data model](tickets/2-data-model.md): Use SwiftData with a `Match` and `Swing` relationship. Target iOS 17 and watchOS 10+.
- [Ticket 3: CoreMotion approach](tickets/3-coremotion-approach.md): Use CoreML (Activity Classification) instead of thresholding. We'll need a data collection phase to build an `.mlmodel` via Create ML.
- [Ticket 4: Scorekeeper UI](tickets/4-scorekeeper-ui.md): Split-screen UI (Them/Us) with a center pill for full Pickleball scoring rules (0-0-2) and side-out logic.

## Not yet specified

*(No remaining fog. Map is complete!)*

## Out of scope
