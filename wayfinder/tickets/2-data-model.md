## Question

How should the core Data Model be structured to encompass match scores, individual strokes (forehand/backhand timestamped), and HealthKit workout summaries?

Labels: wayfinder:prototype
Status: closed

## Resolution

We will use SwiftData. A `Match` will contain `Score`, `Duration`, `CaloriesBurned`, and a one-to-many relationship to `Swing` (timestamp, type: Forehand/Backhand).
