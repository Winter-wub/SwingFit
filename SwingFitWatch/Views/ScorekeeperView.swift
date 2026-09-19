import SwiftUI
import SwiftData
import WatchKit

public struct ScorekeeperView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var motionManager = MotionManager()

    @State private var currentSession: WorkoutSession?
    @State private var currentMatch: Match?
    @State private var matchStartCalories: Double = 0.0
    @State private var matchStartDuration: TimeInterval = 0.0
    @State private var matchHRSamples: [Double] = []
    @State private var matchIndexInSession: Int = 1
    @State private var currentMatchSwingsCount: Int = 0
    @State private var lastBroadcastTime: Date = .distantPast

    @State private var hasStartedPlaying = false
    @State private var selectedTab = 1 // 0: Controls, 1: Active Tracker
    @State private var showEndSessionAlert = false
    @State private var showNewMatchAlert = false
    @State private var showDiscardAlert = false

    public init() {}

    public var body: some View {
        Group {
            if !hasStartedPlaying {
                startSessionView
            } else {
                activeTrackerView
            }
        }
        .onAppear {
            setupRemoteCommandHandler()
        }
        .onChange(of: workoutManager.heartRate) { _, newHR in
            if newHR > 0 {
                matchHRSamples.append(newHR)
            }
            broadcastState()
        }
        .onChange(of: workoutManager.elapsedTime) { _, _ in
            broadcastState()
        }
        .onChange(of: workoutManager.isPaused) { _, _ in
            broadcastState(force: true)
        }
        .onChange(of: hasStartedPlaying) { _, _ in
            broadcastState(force: true)
        }
    }

    // MARK: - Start Session View (Pre-game)
    private var startSessionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 34))
                .foregroundColor(.green)

            Text("SwingFit Tracker")
                .font(.headline.bold())

            Button {
                let nextHand = (motionManager.hittingHand == "right") ? "left" : "right"
                motionManager.setHittingHand(nextHand)
                WKInterfaceDevice.current().play(.click)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                    Text("Wrist: \(motionManager.hittingHand.capitalized)")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                WKInterfaceDevice.current().play(.start)
                Task {
                    await startSession()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Start Match")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onAppear {
            setupRemoteCommandHandler()
            syncAllPastMatches()
            broadcastState(force: true)
        }
    }

    // MARK: - Active Tracker (2-Tab Pager)
    private var activeTrackerView: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Controls & Settings
            controlsTabView
                .tag(0)

            // Tab 1: Live Swing Tracker
            liveTrackerTabView
                .tag(1)
        }
        .tabViewStyle(.page)
        .confirmationDialog("Finish Match?", isPresented: $showNewMatchAlert) {
            Button("Save & Start Next Match") {
                saveCurrentMatch(isSessionEnding: false)
                createNewMatch()
                selectedTab = 1
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("End All Play?", isPresented: $showEndSessionAlert) {
            Button("End & Save to Health", role: .destructive) {
                Task {
                    await endEntireSession()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Discard Match?", isPresented: $showDiscardAlert) {
            Button("Discard Match", role: .destructive) {
                discardCurrentMatch()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Discard this match without saving?")
        }
    }

    // MARK: - Tab 0: Controls View
    private var controlsTabView: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Match \(matchIndexInSession) Controls")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                // Pause / Resume
                Button {
                    WKInterfaceDevice.current().play(.click)
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                        motionManager.startTracking()
                    } else {
                        workoutManager.pauseWorkout()
                        motionManager.stopTracking()
                    }
                } label: {
                    HStack {
                        Image(systemName: workoutManager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .foregroundColor(workoutManager.isPaused ? .green : .yellow)
                        Text(workoutManager.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.gray.opacity(0.25))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Next Match
                Button {
                    WKInterfaceDevice.current().play(.click)
                    showNewMatchAlert = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Finish & Next Match")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.gray.opacity(0.25))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Discard Current Match
                Button {
                    WKInterfaceDevice.current().play(.click)
                    showDiscardAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.orange)
                        Text("Discard Match")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // End Workout Session
                Button {
                    WKInterfaceDevice.current().play(.notification)
                    showEndSessionAlert = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("End Workout")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Handedness Setting
                HStack {
                    Text("Hand:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(motionManager.hittingHand.capitalized) {
                        let next = (motionManager.hittingHand == "right") ? "left" : "right"
                        motionManager.setHittingHand(next)
                    }
                    .font(.caption2.bold())
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Tab 1: Live Tracker Tab View
    private var liveTrackerTabView: some View {
        VStack(spacing: 4) {
            // Header Bar
            HStack {
                HStack(spacing: 2) {
                    Text("M\(matchIndexInSession)")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.3))
                        .cornerRadius(4)
                        .foregroundColor(.yellow)

                    Image(systemName: workoutManager.isPaused ? "pause.fill" : "timer")
                        .foregroundColor(.yellow)
                        .font(.system(size: 8))

                    Text(formatDuration(max(0, workoutManager.elapsedTime - matchStartDuration)))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                Spacer()

                if workoutManager.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 4)

            // Main Swings Card
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(currentMatchSwingsCount)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("SWINGS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .tracking(1.0)
                    }

                    Spacer()

                    // Last detected shot pill
                    VStack(alignment: .trailing, spacing: 2) {
                        if motionManager.lastDetectedType != .unknown {
                            Text(motionManager.lastDetectedType.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colorForShotType(motionManager.lastDetectedType))
                                .lineLimit(1)

                            Text(String(format: "%.1f G", motionManager.lastAcceleration))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Ready")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.neutralCard)
            .cornerRadius(12)

            // Heart Rate & Calories (This Match)
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 9))
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    Text("bpm")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.neutralCard)
                .cornerRadius(8)

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.pink)
                        .font(.system(size: 9))
                    Text("\(Int(max(0, workoutManager.activeCalories - matchStartCalories)))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.pink)
                    Text("cal")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.neutralCard)
                .cornerRadius(8)
            }

            // Quick Actions: Pause & End Match
            HStack(spacing: 4) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                        motionManager.startTracking()
                    } else {
                        workoutManager.pauseWorkout()
                        motionManager.stopTracking()
                    }
                } label: {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(workoutManager.isPaused ? .green : .yellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    showNewMatchAlert = true
                } label: {
                    Text("End Match")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }

    private func colorForShotType(_ type: SwingType) -> Color {
        switch type {
        case .forehand: return .green
        case .backhand: return .blue
        case .dink: return .orange
        case .smash: return .red
        case .serve: return .yellow
        case .unknown: return .gray
        }
    }

    // MARK: - Actions & Logic
    private func startSession() async {
        _ = await workoutManager.requestAuthorization()
        await workoutManager.startWorkout()
        motionManager.startTracking()

        let session = WorkoutSession(startDate: Date())
        modelContext.insert(session)
        currentSession = session
        matchIndexInSession = 1

        createNewMatch()
        hasStartedPlaying = true
        selectedTab = 1
    }

    private func createNewMatch() {
        let match = Match(
            startDate: Date(),
            myScore: 0,
            opponentScore: 0
        )
        match.session = currentSession
        modelContext.insert(match)
        currentMatch = match
        currentSession?.matches?.append(match)

        matchStartCalories = workoutManager.activeCalories
        matchStartDuration = workoutManager.elapsedTime
        matchHRSamples.removeAll()
        currentMatchSwingsCount = 0

        motionManager.onSwingDetected = { swingType, peakAcc in
            WKInterfaceDevice.current().play(.click)
            let swing = Swing(timestamp: Date(), swingType: swingType, peakAcceleration: peakAcc)
            match.swings?.append(swing)
            currentMatchSwingsCount += 1
            broadcastState(force: true)
        }
    }

    private func saveCurrentMatch(isSessionEnding: Bool) {
        guard let match = currentMatch else { return }
        match.endDate = Date()

        // Calculate delta calories and duration for this specific match
        let deltaCalories = max(0, workoutManager.activeCalories - matchStartCalories)
        let deltaDuration = max(0, workoutManager.elapsedTime - matchStartDuration)
        let avgHR: Double
        if !matchHRSamples.isEmpty {
            avgHR = matchHRSamples.reduce(0, +) / Double(matchHRSamples.count)
        } else {
            avgHR = workoutManager.heartRate
        }

        match.activeCalories = deltaCalories
        match.duration = deltaDuration
        match.averageHeartRate = avgHR
        match.isComplete = true
        match.session = currentSession
        try? modelContext.save()

        // Sync match to iPhone immediately
        WatchSyncManager.shared.sendMatch(match)

        if !isSessionEnding {
            matchIndexInSession += 1
        }
    }

    private func endEntireSession() async {
        saveCurrentMatch(isSessionEnding: true)
        let stats = await workoutManager.endWorkout()
        motionManager.stopTracking()

        if let session = currentSession {
            session.endDate = Date()
            session.totalCalories = stats.calories
            session.totalDuration = stats.duration
            session.averageHeartRate = stats.avgHeartRate
            session.isComplete = true
            try? modelContext.save()

            // Sync full session to iPhone
            WatchSyncManager.shared.sendSession(session)
        }

        hasStartedPlaying = false
        currentMatch = nil
        currentSession = nil
        matchHRSamples.removeAll()
        broadcastState(force: true)
    }

    private func discardCurrentMatch() {
        guard let match = currentMatch else { return }
        WatchSyncManager.shared.deleteMatch(id: match.id)

        let remainingMatches = (currentSession?.matches ?? []).filter { $0.id != match.id }
        if remainingMatches.isEmpty {
            Task {
                _ = await workoutManager.endWorkout()
                motionManager.stopTracking()
                if let session = currentSession {
                    modelContext.delete(session)
                    try? modelContext.save()
                }
                hasStartedPlaying = false
                currentMatch = nil
                currentSession = nil
                matchHRSamples.removeAll()
                broadcastState(force: true)
            }
        } else {
            createNewMatch()
            selectedTab = 1
            broadcastState(force: true)
        }
    }

    // MARK: - Remote Control & Telemetry Sync
    private func setupRemoteCommandHandler() {
        WatchSyncManager.shared.onCommandReceived = { command in
            Task { @MainActor in
                self.handleRemoteCommand(command)
            }
        }
    }

    private func handleRemoteCommand(_ command: String) {
        switch command {
        case "startMatch":
            if !hasStartedPlaying {
                WKInterfaceDevice.current().play(.start)
                Task {
                    await startSession()
                    broadcastState(force: true)
                }
            } else if workoutManager.isPaused {
                WKInterfaceDevice.current().play(.click)
                workoutManager.resumeWorkout()
                motionManager.startTracking()
                broadcastState(force: true)
            }
        case "pauseMatch":
            if hasStartedPlaying && !workoutManager.isPaused {
                WKInterfaceDevice.current().play(.click)
                workoutManager.pauseWorkout()
                motionManager.stopTracking()
                broadcastState(force: true)
            }
        case "resumeMatch":
            if hasStartedPlaying && workoutManager.isPaused {
                WKInterfaceDevice.current().play(.click)
                workoutManager.resumeWorkout()
                motionManager.startTracking()
                broadcastState(force: true)
            }
        case "endMatch":
            if hasStartedPlaying {
                WKInterfaceDevice.current().play(.notification)
                Task {
                    await endEntireSession()
                    broadcastState(force: true)
                }
            }
        case "discardMatch":
            if hasStartedPlaying {
                WKInterfaceDevice.current().play(.click)
                discardCurrentMatch()
                broadcastState(force: true)
            }
        default:
            break
        }
    }

    private func broadcastState(force: Bool = false) {
        guard hasStartedPlaying else {
            WatchSyncManager.shared.sendMatchStateToPhone(
                isRunning: false,
                isPaused: false,
                swingsCount: 0,
                elapsedTime: 0,
                heartRate: 0,
                calories: 0
            )
            return
        }

        let now = Date()
        if !force && now.timeIntervalSince(lastBroadcastTime) < 2.0 {
            return
        }
        lastBroadcastTime = now

        let deltaDuration = max(0, workoutManager.elapsedTime - matchStartDuration)
        let deltaCalories = max(0, workoutManager.activeCalories - matchStartCalories)
        WatchSyncManager.shared.sendMatchStateToPhone(
            isRunning: true,
            isPaused: workoutManager.isPaused,
            swingsCount: currentMatchSwingsCount,
            elapsedTime: deltaDuration,
            heartRate: workoutManager.heartRate,
            calories: deltaCalories
        )
    }

    private func syncAllPastMatches() {
        WatchSyncManager.shared.purgeDeletedMatchesLocally()

        let descriptor = FetchDescriptor<Match>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let matches = try? modelContext.fetch(descriptor) {
            for m in matches {
                if WatchSyncManager.shared.isMatchDeleted(m.id) {
                    if let session = m.session {
                        session.matches?.removeAll(where: { $0.id == m.id })
                    }
                    modelContext.delete(m)
                    try? modelContext.save()
                    continue
                }
                WatchSyncManager.shared.sendMatch(m)
            }
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Color {
    static let neutralCard = Color(red: 0.14, green: 0.14, blue: 0.16)
}
