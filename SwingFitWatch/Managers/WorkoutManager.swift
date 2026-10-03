import Foundation
import Combine
import HealthKit

@MainActor
public final class WorkoutManager: NSObject, ObservableObject {
    public let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published public var isWorkoutRunning = false
    @Published public var isPaused = false
    @Published public var heartRate: Double = 0.0
    @Published public var activeCalories: Double = 0.0
    @Published public var elapsedTime: TimeInterval = 0.0

    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0.0
    private var lastResumeDate: Date?

    public override init() {
        super.init()
    }

    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let typesToShare: Set = [
            HKWorkoutType.workoutType()
        ]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKWorkoutType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            print("Failed to authorize HealthKit: \(error.localizedDescription)")
            return false
        }
    }

    public func startWorkout(sport: SportType) async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = sport == .badminton ? .badminton : .pickleball
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            session?.delegate = self
            builder?.delegate = self

            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            let now = Date()
            startDate = now
            lastResumeDate = now
            accumulatedTime = 0.0
            session?.startActivity(with: now)
            try await builder?.beginCollection(at: now)

            isWorkoutRunning = true
            isPaused = false
            startTimer()
        } catch {
            print("Error starting workout: \(error.localizedDescription)")
        }
    }

    public func pauseWorkout() {
        guard session != nil, !isPaused else { return }
        session?.pause()
        isPaused = true
        stopTimer()
        if let resume = lastResumeDate {
            accumulatedTime += Date().timeIntervalSince(resume)
            elapsedTime = accumulatedTime
        }
    }

    public func resumeWorkout() {
        guard session != nil, isPaused else { return }
        let now = Date()
        lastResumeDate = now
        session?.resume()
        isPaused = false
        startTimer()
    }

    public func endWorkout() async -> (calories: Double, avgHeartRate: Double, duration: TimeInterval) {
        guard let session = session, let builder = builder else {
            return (activeCalories, heartRate, elapsedTime)
        }

        stopTimer()
        if !isPaused, let resume = lastResumeDate {
            accumulatedTime += Date().timeIntervalSince(resume)
            elapsedTime = accumulatedTime
        }
        session.end()

        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
            print("Successfully finished and saved HKWorkout!")
        } catch {
            print("Error finishing workout: \(error.localizedDescription)")
        }

        let summary = (calories: activeCalories, avgHeartRate: heartRate, duration: elapsedTime)
        isWorkoutRunning = false
        isPaused = false
        self.session = nil
        self.builder = nil
        return summary
    }

    private func startTimer() {
        let start = Date()
        self.startDate = start
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateForStatistics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                heartRate = value
            }
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            let energyUnit = HKUnit.kilocalorie()
            if let value = statistics.sumQuantity()?.doubleValue(for: energyUnit) {
                activeCalories = value
            }
        default:
            break
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.isWorkoutRunning = (toState == .running || toState == .paused)
            self.isPaused = (toState == .paused)
        }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            if let statistics = workoutBuilder.statistics(for: quantityType) {
                Task { @MainActor in
                    self.updateForStatistics(statistics)
                }
            }
        }
    }
}
