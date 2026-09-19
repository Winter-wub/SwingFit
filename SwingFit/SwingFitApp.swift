import SwiftUI
import SwiftData

@main
struct SwingFitApp: App {
    let sharedModelContainer: ModelContainer
    @StateObject private var coachService: CoachService

    init() {
        let schema = Schema([
            WorkoutSession.self,
            Match.self,
            Swing.self,
            CoachThread.self,
            CoachMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        sharedModelContainer = container
        WatchSyncManager.shared.modelContext = container.mainContext
        _coachService = StateObject(
            wrappedValue: CoachService(modelContext: container.mainContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(coachService)
        }
        .modelContainer(sharedModelContainer)
    }
}
