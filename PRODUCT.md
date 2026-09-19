# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack
SwiftUI, SwiftData, CloudKit, HealthKit, CoreMotion, CoreML.
Minimum deployment target: iOS 17, watchOS 10.

## Users
Pickleball players who own an Apple Watch and want to track their match scores, health metrics, and swing analysis without needing to carry their iPhone on the court.

## Product Purpose
To provide a standalone Apple Watch app and companion iOS app that seamlessly integrates health tracking (Apple Fitness/HealthKit) and automated swing analysis (Forehand, Backhand, Dink, Smash) with intelligent post-game coaching recommendations to help players improve their game.

## Positioning
Unlike generic workout trackers or manual scorekeepers, SwingFit provides zero-friction on-court tracking using the Apple Watch motion sensors to automatically capture strokes and intensity, paired with an intelligent iPhone coaching dashboard.

## Operating Context
Used on the court during active play via Apple Watch (zero interaction required; plays in background). The companion iOS app is used post-match for detailed swing breakdown, intensity graphs, and tactical coaching tips.

## Capabilities and Constraints
- **Watch App**: Standalone. Records health data to Apple Health (1 continuous HKWorkoutSession). Uses CoreMotion to automatically detect and classify swings without tapping.
- **iOS App**: Coaching Hub. Syncs data automatically via Bluetooth/Local WCSession. Displays shot distribution, power trends, and coach recommendations.
- **Constraints**: Requires wearing watch on the hitting hand for accurate gyroscope rotation mapping.

## Brand Commitments
Name: "SwingFit". Focus on zero-friction tracking, athletic coaching aesthetics, and native Apple ecosystem feel.

## Evidence on Hand
Native SwiftData models, WatchConnectivity sync, and CoreMotion 50Hz sensor engine.

## Product Principles
1. **Zero Interaction on Court**: Play without looking or tapping on the screen. The watch records everything automatically.
2. **Actionable Coaching**: Turn raw motion data into clear, human-understandable advice (e.g. shot balance, fatigue detection).
3. **Frictionless Sync**: Instant local Bluetooth transfer from Watch to iPhone.
4. **Native Feel**: Seamlessly integrates with Apple Health workouts and rings.

## Accessibility & Inclusion
High contrast for outdoor visibility (glare on the court). Large tap targets on the Watch for quick interactions during play.
