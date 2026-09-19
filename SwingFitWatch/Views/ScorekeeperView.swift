import SwiftUI
import SwiftData
import WatchKit
import Combine

public enum GameMode: String, CaseIterable, Identifiable {
    case rally = "Free Rally"
    case match = "Match Score"
    public var id: String { rawValue }
}

public struct ScorekeeperView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var motionManager = MotionManager()

    // Sport and Mode selection
    @State private var selectedSport: SportType = .pickleball
    @State private var selectedGameMode: GameMode = .rally

    // Scoring engines
    @StateObject private var pickleballEngine = PickleballScoreEngine()
    @StateObject private var badmintonEngine = BadmintonScoreEngine()

    // Session and Match tracking
    @State private var currentSession: WorkoutSession?
    @State private var currentMatch: Match?
    @State private var matchStartCalories: Double = 0.0
    @State private var matchStartDuration: TimeInterval = 0.0
    @State private var matchHRSamples: [Double] = []
    @State private var matchIndexInSession: Int = 1
    @State private var currentMatchSwingsCount: Int = 0
    @State private var lastBroadcastTime: Date = .distantPast

    @State private var hasStartedPlaying = false
    @State private var selectedTab = 1 // 0: Glass Controls, 1: Active HUD / Scoring
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

    // MARK: - 1. Start Session View (Apple Liquid Glass Setup)
    private var startSessionView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Liquid Glass Header Banner
                HStack(spacing: 6) {
                    Image(systemName: selectedSport == .pickleball ? "figure.pickleball" : "figure.badminton")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selectedSport == .pickleball ? .green : .purple)
                    Text("SWINGFIT")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.vertical, 4)

                // Sport Selector Glass Segment
                HStack(spacing: 4) {
                    sportPill(sport: .pickleball, icon: "figure.pickleball", title: "Pickleball", tint: .green)
                    sportPill(sport: .badminton, icon: "figure.badminton", title: "Badminton", tint: .purple)
                }
                .padding(3)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Mode Selector (Rally vs Match)
                HStack(spacing: 4) {
                    modePill(mode: .rally, icon: "bolt.heart.fill", title: "Free Rally")
                    modePill(mode: .match, icon: "trophy.fill", title: "Match")
                }
                .padding(3)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Wrist Handedness Glass Pill
                Button {
                    let nextHand = (motionManager.hittingHand == "right") ? "left" : "right"
                    motionManager.setHittingHand(nextHand)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10))
                        Text("Wrist: \(motionManager.hittingHand.capitalized)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.yellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.yellow.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Big Start Glass Button
                Button {
                    WKInterfaceDevice.current().play(.start)
                    Task {
                        await startSession()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .black))
                        Text(selectedGameMode == .rally ? "Start Rally" : "Start Match")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: selectedSport == .pickleball 
                                ? [Color(red: 0.2, green: 0.95, blue: 0.5), Color(red: 0.1, green: 0.8, blue: 0.35)]
                                : [Color(red: 0.75, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.2, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: (selectedSport == .pickleball ? Color.green : Color.purple).opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            setupRemoteCommandHandler()
            syncAllPastMatches()
            broadcastState(force: true)
        }
    }

    private func sportPill(sport: SportType, icon: String, title: String, tint: Color) -> some View {
        Button {
            selectedSport = sport
            WKInterfaceDevice.current().play(.click)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(selectedSport == sport ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selectedSport == sport
                    ? tint.opacity(0.35)
                    : Color.clear
            )
            .cornerRadius(11)
        }
        .buttonStyle(.plain)
    }

    private func modePill(mode: GameMode, icon: String, title: String) -> some View {
        Button {
            selectedGameMode = mode
            WKInterfaceDevice.current().play(.click)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(selectedGameMode == mode ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selectedGameMode == mode
                    ? Color.white.opacity(0.2)
                    : Color.clear
            )
            .cornerRadius(11)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Active Tracker (Apple Liquid Glass TabView)
    private var activeTrackerView: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Controls & Setting Screen (Swipe right to pause/finish)
            controlsTabView
                .tag(0)

            // Tab 1: Primary Action Screen (Dynamic depending on Match vs Rally)
            Group {
                if selectedGameMode == .match {
                    splitScreenMatchScorerView
                } else {
                    freeRallyHUDView
                }
            }
            .tag(1)
        }
        .tabViewStyle(.page)
        .confirmationDialog("Finish Match?", isPresented: $showNewMatchAlert) {
            Button("Save & Next Game") {
                saveCurrentMatch(isSessionEnding: false)
                createNewMatch()
                selectedTab = 1
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("End Workout?", isPresented: $showEndSessionAlert) {
            Button("End & Save Session", role: .destructive) {
                Task {
                    await endEntireSession()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Discard Match?", isPresented: $showDiscardAlert) {
            Button("Discard Without Saving", role: .destructive) {
                discardCurrentMatch()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Split-Screen Match Scorer (Ergonomic Touch Targets)
    private var splitScreenMatchScorerView: some View {
        VStack(spacing: 2) {
            // Top Half: US Score Touch Area
            Button {
                handleScorePoint(for: .us)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("US")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.green)
                            if selectedSport == .pickleball && pickleballEngine.servingTeam == .us {
                                HStack(spacing: 2) {
                                    Circle().fill(Color.yellow).frame(width: 5, height: 5)
                                    Text("S\(pickleballEngine.serverNumber)")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .padding(.leading, 10)

                        Spacer()

                        Text("\(getScore(for: .us))")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.trailing, 10)
                    }
                }
            }
            .buttonStyle(.plain)

            // Center Telemetry Bar (Callout + Swings + HR)
            HStack(spacing: 4) {
                // Callout pill
                Text(getScoreCallout())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                // Heart rate
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 8))
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Swings count
                HStack(spacing: 2) {
                    Image(systemName: "figure.pickleball")
                        .foregroundColor(.green)
                        .font(.system(size: 8))
                    Text("\(currentMatchSwingsCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)

            // Bottom Half: THEM Score Touch Area
            Button {
                handleScorePoint(for: .them)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("THEM")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.cyan)
                            if selectedSport == .pickleball && pickleballEngine.servingTeam == .them {
                                HStack(spacing: 2) {
                                    Circle().fill(Color.yellow).frame(width: 5, height: 5)
                                    Text("S\(pickleballEngine.serverNumber)")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .padding(.leading, 10)

                        Spacer()

                        Text("\(getScore(for: .them))")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.trailing, 10)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Free Rally HUD View (Big Glanceable Kinematics)
    private var freeRallyHUDView: some View {
        VStack(spacing: 4) {
            // Header: Timer & Sport Tag
            HStack {
                HStack(spacing: 3) {
                    Circle()
                        .fill(workoutManager.isPaused ? Color.yellow : Color.green)
                        .frame(width: 6, height: 6)
                    Text(formatDuration(max(0, workoutManager.elapsedTime - matchStartDuration)))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                Spacer()

                Text(selectedSport == .pickleball ? "PICKLEBALL" : "BADMINTON")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((selectedSport == .pickleball ? Color.green : Color.purple).opacity(0.25))
                    .foregroundColor(selectedSport == .pickleball ? .green : .purple)
                    .cornerRadius(5)
            }
            .padding(.horizontal, 4)

            // Giant Center Glass Display (Total Swings)
            VStack(spacing: 1) {
                Text("\(currentMatchSwingsCount)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)

                Text("TOTAL STROKES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(selectedSport == .pickleball ? .green : .purple)
                    .tracking(1.0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Last Shot Badge & Acceleration
            HStack {
                if motionManager.lastDetectedType != .unknown {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForShotType(motionManager.lastDetectedType))
                            .frame(width: 6, height: 6)
                        Text(motionManager.lastDetectedType.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(String(format: "%.1f G", motionManager.lastAcceleration))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(colorForShotType(motionManager.lastDetectedType))
                } else {
                    Text("Swing detection active...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)

            // Bottom Telemetry Bar: Heart Rate & Calories
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
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.07))
                .cornerRadius(7)

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
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.07))
                .cornerRadius(7)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Tab 0: Liquid Glass Action Menu (Swipe Right)
    private var controlsTabView: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("SESSION CONTROLS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                    .padding(.top, 2)

                // Pause / Resume Glass Button
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
                        Text(workoutManager.isPaused ? "Resume Play" : "Pause Play")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Finish / Next Match Button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    showNewMatchAlert = true
                } label: {
                    HStack {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.blue)
                        Text("Finish & Next Match")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // End Workout & Save to Apple Health
                Button {
                    WKInterfaceDevice.current().play(.notification)
                    showEndSessionAlert = true
                } label: {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                        Text("End Workout Session")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.35), lineWidth: 1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Discard Button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    showDiscardAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.orange)
                        Text("Discard This Game")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Scoring Helpers
    private func handleScorePoint(for team: Team) {
        WKInterfaceDevice.current().play(.click)
        if selectedSport == .pickleball {
            pickleballEngine.scorePoint(scoringTeam: team)
            if let match = currentMatch {
                match.myScore = pickleballEngine.myScore
                match.opponentScore = pickleballEngine.opponentScore
            }
        } else {
            badmintonEngine.scorePoint(side: team == .us ? .us : .them)
            if let match = currentMatch {
                match.myScore = badmintonEngine.myScore
                match.opponentScore = badmintonEngine.opponentScore
            }
        }
        broadcastState(force: true)
    }

    private func getScore(for team: Team) -> Int {
        if selectedSport == .pickleball {
            return team == .us ? pickleballEngine.myScore : pickleballEngine.opponentScore
        } else {
            return team == .us ? badmintonEngine.myScore : badmintonEngine.opponentScore
        }
    }

    private func getScoreCallout() -> String {
        if selectedSport == .pickleball {
            return pickleballEngine.calloutString
        } else {
            return badmintonEngine.scoreString
        }
    }

    private func colorForShotType(_ type: SwingType) -> Color {
        switch type {
        case .forehand: return .green
        case .backhand: return .blue
        case .dink: return .orange
        case .smash: return .red
        case .serve: return .yellow
        case .clear: return .purple
        case .dropShot: return .cyan
        case .drive: return .indigo
        case .netShot: return .mint
        case .lift: return .teal
        case .unknown: return .gray
        @unknown default: return .gray
        }
    }

    // MARK: - Actions & Session Lifecyle
    private func startSession() async {
        _ = await workoutManager.requestAuthorization()
        await workoutManager.startWorkout()
        motionManager.startTracking()

        let session = WorkoutSession(startDate: Date())
        modelContext.insert(session)
        currentSession = session
        matchIndexInSession = 1

        // Reset engines
        pickleballEngine.resetGame()
        badmintonEngine.resetMatch()

        createNewMatch()
        hasStartedPlaying = true
        selectedTab = 1
    }

    private func createNewMatch() {
        let match = Match(
            startDate: Date(),
            myScore: 0,
            opponentScore: 0,
            sport: selectedSport
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

    // MARK: - Remote Control & Sync Handlers
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
