import SwiftUI
import SwiftData
import WatchKit
import HealthKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("ExtensionDelegate received workoutConfiguration: \(workoutConfiguration)")
        Task { @MainActor in
            WatchSyncManager.shared.triggerCommand("startMatch")
        }
    }
}

@main
struct SwingFitWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Match.self,
            Swing.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        WatchSyncManager.shared.modelContext = sharedModelContainer.mainContext
    }

    var body: some Scene {
        WindowGroup {
            ScorekeeperView()
        }
        .modelContainer(sharedModelContainer)
    }
}
