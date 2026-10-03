import Foundation
import HealthKit

/// Replaces a saved HKWorkout with one of a different activity type.
/// HealthKit workouts are immutable, so a new workout is built over the same
/// time range and linked to the existing calorie and heart-rate samples, then
/// the old workout is deleted. The samples themselves are never touched, so
/// daily Activity totals stay the same.
@MainActor
public final class HealthWorkoutSportEditor {
    public static let shared = HealthWorkoutSportEditor()

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    private init() {}

    public func updateWorkout(containing date: Date, to sport: SportType) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let activityType: HKWorkoutActivityType = sport == .badminton ? .badminton : .pickleball

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKWorkoutType.workoutType(), heartRateType, activeEnergyType],
                read: [HKWorkoutType.workoutType(), heartRateType, activeEnergyType]
            )

            guard let old = try await findWorkout(containing: date) else {
                print("HealthWorkoutSportEditor: no SwingFit workout found around \(date)")
                return
            }

            let samples = try await watchSamples(during: old)
            // Also repairs workouts that lost their calorie link in an earlier rebuild.
            let missingCalories = old.statistics(for: activeEnergyType)?.sumQuantity() == nil
                && samples.contains { $0.quantityType == activeEnergyType }
            guard old.workoutActivityType != activityType || missingCalories else { return }

            let newWorkout = try await recreate(old, as: activityType, samples: samples)
            do {
                try await healthStore.delete(old)
            } catch {
                try? await healthStore.delete(newWorkout)
                throw error
            }
            let kcal = newWorkout.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            print("HealthWorkoutSportEditor: workout at \(old.startDate) rebuilt as \(sport.rawValue) with \(samples.count) samples, \(Int(kcal)) kcal")
        } catch {
            print("HealthWorkoutSportEditor: failed to change workout sport: \(error.localizedDescription)")
        }
    }

    private func findWorkout(containing date: Date) async throws -> HKWorkout? {
        let window: TimeInterval = 12 * 60 * 60
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-window), end: date.addingTimeInterval(window)))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let workouts = try await descriptor.result(for: healthStore)
        return workouts.first {
            isOwnSource($0.sourceRevision.source)
                && $0.startDate <= date.addingTimeInterval(60)
                && $0.endDate >= date
        }
    }

    /// Workouts recorded by the watch app are attributed to the iPhone app's
    /// bundle ID, so accept either.
    private func isOwnSource(_ source: HKSource) -> Bool {
        let watchID = HKSource.default().bundleIdentifier
        let phoneID = watchID.replacingOccurrences(of: ".watchkitapp", with: "")
        return source.bundleIdentifier == watchID || source.bundleIdentifier == phoneID
    }

    /// Heart-rate and calorie samples the watch recorded during the workout.
    /// The live builder stores these under the watch's own Health source, not
    /// the app's, so select by device rather than by source.
    private func watchSamples(during workout: HKWorkout) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [
                .quantitySample(type: heartRateType, predicate: predicate),
                .quantitySample(type: activeEnergyType, predicate: predicate)
            ],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore).filter {
            $0.device?.model == "Watch" || isOwnSource($0.sourceRevision.source)
        }
    }

    private func recreate(
        _ old: HKWorkout,
        as activityType: HKWorkoutActivityType,
        samples: [HKQuantitySample]
    ) async throws -> HKWorkout {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: old.device)
        do {
            try await builder.beginCollection(at: old.startDate)
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            if let events = old.workoutEvents, !events.isEmpty {
                try await builder.addWorkoutEvents(events)
            }
            if let metadata = old.metadata, !metadata.isEmpty {
                try? await builder.addMetadata(metadata)
            }
            try await builder.endCollection(at: old.endDate)

            guard let workout = try await builder.finishWorkout() else {
                throw HKError(.errorInvalidArgument)
            }
            return workout
        } catch {
            builder.discardWorkout()
            throw error
        }
    }
}
