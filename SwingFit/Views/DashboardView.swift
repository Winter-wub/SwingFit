import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.startDate, order: .reverse) private var matches: [Match]
    @ObservedObject private var syncManager = WatchSyncManager.shared
    
    @AppStorage("hittingHand") private var hittingHand: String = "right"
    @AppStorage("swingSensitivity") private var swingSensitivity: String = "medium"
    
    @State private var selectedTab: Int = 0 // 0: Court HUD, 1: Analytics & AI, 2: Gear & Settings
    @State private var expandedMatchId: UUID?
    @State private var showEndMatchAlert: Bool = false
    @State private var showDiscardMatchAlert: Bool = false

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Court HUD (Live Tracking & Quick Remote)
            NavigationStack {
                liveCourtView
                    .navigationTitle("Court HUD")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            syncIndicatorButton
                        }
                    }
            }
            .tabItem {
                Label("Court HUD", systemImage: "figure.pickleball")
            }
            .tag(0)

            // Tab 1: Match Analytics & Gemini AI Coach
            NavigationStack {
                analyticsView
                    .navigationTitle("Match Analytics")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            syncIndicatorButton
                        }
                    }
            }
            .tabItem {
                Label("Analytics & AI", systemImage: "chart.bar.xaxis")
            }
            .tag(1)

            // Tab 2: Gear & Settings
            NavigationStack {
                settingsView
                    .navigationTitle("Gear & Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(.emeraldGreen)
        .onAppear {
            syncManager.requestSyncFromWatch()
        }
    }

    private var syncIndicatorButton: some View {
        Button {
            syncManager.requestSyncFromWatch()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                if syncManager.isReachable {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: - TAB 0: Live Court HUD View (Liquid Glass)
    private var liveCourtView: some View {
        ZStack {
            liquidGlassBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Match Control Card (Liquid Glass)
                    matchControlCard

                    // Coach Insight Card
                    coachInsightCard

                    // Quick Glance Stats
                    statsSummaryGrid
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - TAB 1: Analytics & AI View
    private var analyticsView: some View {
        ZStack {
            liquidGlassBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HISTORY & AI BREAKDOWN")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                                .foregroundColor(.emeraldGreen)
                            Text("\(matches.count) Recorded Matches")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Matches List
                    if matches.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                                MatchAnalysisCardView(
                                    match: match,
                                    matchNumber: matches.count - index,
                                    isExpanded: expandedMatchId == match.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if expandedMatchId == match.id {
                                                expandedMatchId = nil
                                            } else {
                                                expandedMatchId = match.id
                                            }
                                        }
                                    },
                                    onDelete: {
                                        withAnimation {
                                            if expandedMatchId == match.id {
                                                expandedMatchId = nil
                                            }
                                            syncManager.deleteMatch(id: match.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - TAB 2: Gear & Settings View
    private var settingsView: some View {
        ZStack {
            liquidGlassBackground

            ScrollView {
                VStack(spacing: 18) {
                    calibrationCard
                    deviceStatusCard
                }
                .padding()
            }
        }
    }

    // MARK: - Liquid Glass Background Layer
    private var liquidGlassBackground: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            // Subtle luminous ambient specular lighting (Apple Glass glow)
            GeometryReader { geo in
                Circle()
                    .fill(Color.emeraldGreen.opacity(0.1))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -80, y: -60)

                Circle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: geo.size.width - 160, y: geo.size.height * 0.4)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Match Remote Control Card (Liquid Glass)
    private var matchControlCard: some View {
        Group {
            if syncManager.isWatchMatchRunning {
                activeMatchHUDCard
            } else {
                startMatchPromptCard
            }
        }
        .padding(.horizontal)
        .confirmationDialog("End Match?", isPresented: $showEndMatchAlert, titleVisibility: .visible) {
            Button("End & Save Match", role: .destructive) {
                withAnimation {
                    syncManager.sendCommandToWatch("endMatch")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will finish the match on your Apple Watch, compute the summary, and sync data to your iPhone.")
        }
        .confirmationDialog("Discard Match?", isPresented: $showDiscardMatchAlert, titleVisibility: .visible) {
            Button("Discard Match", role: .destructive) {
                withAnimation {
                    syncManager.sendCommandToWatch("discardMatch")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will discard the ongoing match without saving any swing data.")
        }
    }

    private var startMatchPromptCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.emeraldGreen.opacity(0.35), Color.emeraldGreen.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(Color.emeraldGreen.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "figure.pickleball")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.emeraldGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready for Court Action?")
                        .font(.headline.bold())
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(syncManager.isReachable ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(syncManager.isReachable ? "Apple Watch Paired & Active" : "Will launch Apple Watch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    syncManager.startMatchFromPhone()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .heavy))
                    Text("Start Live Court Session")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.emeraldGreen, Color(red: 0.2, green: 0.9, blue: 0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.emeraldGreen.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private var activeMatchHUDCard: some View {
        VStack(spacing: 16) {
            // Live Status Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncManager.isWatchMatchPaused ? Color.yellow : Color.green)
                        .frame(width: 9, height: 9)

                    Text(syncManager.isWatchMatchPaused ? "SESSION PAUSED" : "LIVE COURT TRACKING")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(syncManager.isWatchMatchPaused ? .yellow : .green)
                        .tracking(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((syncManager.isWatchMatchPaused ? Color.yellow : Color.green).opacity(0.15))
                .cornerRadius(8)

                Spacer()

                // Live Timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                    Text(formatLiveDuration(syncManager.liveDuration))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.primary)
            }

            // 3-Column Live Telemetry (Liquid Glass tiles)
            HStack(spacing: 10) {
                // Swings Count
                VStack(spacing: 2) {
                    Text("\(syncManager.liveSwingsCount)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                    Text("STROKES")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.08))
                .cornerRadius(14)

                // Heart Rate
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text("\(Int(syncManager.liveHeartRate))")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                    }
                    Text("BPM")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(14)

                // Calories
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.pink)
                        Text("\(Int(syncManager.liveCalories))")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.pink)
                    }
                    Text("CALORIES")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink.opacity(0.08))
                .cornerRadius(14)
            }

            // Controls: Pause/Resume, End, Discard
            HStack(spacing: 10) {
                // Pause / Resume Button
                Button {
                    withAnimation {
                        syncManager.sendCommandToWatch(syncManager.isWatchMatchPaused ? "resumeMatch" : "pauseMatch")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: syncManager.isWatchMatchPaused ? "play.fill" : "pause.fill")
                        Text(syncManager.isWatchMatchPaused ? "Resume" : "Pause")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(syncManager.isWatchMatchPaused ? .green : .yellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((syncManager.isWatchMatchPaused ? Color.green : Color.yellow).opacity(0.18))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                // End Match Button
                Button {
                    showEndMatchAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                        Text("End Session")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }

            // Discard Match Option
            Button {
                showDiscardMatchAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Discard this session without saving")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, -2)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [(syncManager.isWatchMatchPaused ? Color.yellow : Color.green).opacity(0.5), .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
    }

    private func formatLiveDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Coach Insight Card (Liquid Glass)
    private var coachInsightCard: some View {
        let totalSwings = matches.reduce(0) { $0 + $1.totalSwings }
        let totalFh = matches.reduce(0) { $0 + $1.forehandCount }
        let totalDinks = matches.reduce(0) { $0 + $1.dinkCount }
        let fhRatio = totalSwings > 0 ? Int(Double(totalFh) / Double(totalSwings) * 100) : 50

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text("💡")
                    .font(.system(size: 22))
                    .padding(8)
                    .background(Color.emeraldGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("GEMINI COACH INSIGHT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.emeraldGreen)
                            .tracking(1.0)
                        Spacer()
                        if !matches.isEmpty {
                            Text("From \(matches.count) games")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    coachAdviceContent(fhRatio: fhRatio, totalDinks: totalDinks)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func coachAdviceContent(fhRatio: Int, totalDinks: Int) -> some View {
        if matches.isEmpty {
            Text("Start your first rally or match on Apple Watch. SwingFit will track your stroke mechanics and intensity to provide personalized AI coaching.")
        } else if fhRatio > 65 {
            Text("You are favoring your Forehand heavily (\(fhRatio)%). Skilled opponents will attack your backhand corner. Position earlier to take more Backhand drives.")
        } else if totalDinks > 15 {
            Text("Excellent kitchen dinking control! You hit \(totalDinks) touch dinks, forcing defensive resets. Keep wrist relaxed and stable.")
        } else {
            let bhRatio = 100 - fhRatio
            Text("Balanced court coverage! Forehand (\(fhRatio)%) and Backhand (\(bhRatio)%) ratio shows high consistency across defensive and attacking phases.")
        }
    }

    // MARK: - Top Stat Summary Cards
    private var statsSummaryGrid: some View {
        let totalSwings = matches.reduce(0) { $0 + $1.totalSwings }
        let totalFh = matches.reduce(0) { $0 + $1.forehandCount }
        let fhPercent = totalSwings > 0 ? Int(Double(totalFh) / Double(totalSwings) * 100) : 0
        let bhPercent = totalSwings > 0 ? 100 - fhPercent : 0

        let allAvgIntensities = matches.compactMap { $0.averageIntensity > 0 ? $0.averageIntensity : nil }
        let overallAvgIntensity = allAvgIntensities.isEmpty ? 0.0 : allAvgIntensities.reduce(0.0, +) / Double(allAvgIntensities.count)
        let peakIntensity = matches.compactMap { $0.peakIntensity }.max() ?? 0.0

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryTile(
                title: "TOTAL STROKES",
                value: "\(totalSwings)",
                subtext: "\(matches.count) sessions total",
                icon: "waveform.path.ecg",
                color: .blue
            )

            summaryTile(
                title: "F / B BALANCE",
                value: "\(fhPercent) / \(bhPercent)%",
                subtext: "Forehand vs Backhand",
                icon: "arrow.left.and.right.circle",
                color: .emeraldGreen
            )

            summaryTile(
                title: "AVG INTENSITY",
                value: String(format: "%.1f G", overallAvgIntensity),
                subtext: "Racket acceleration",
                icon: "speedometer",
                color: .orange
            )

            summaryTile(
                title: "PEAK POWER",
                value: String(format: "%.1f G", peakIntensity),
                subtext: "Maximum recorded",
                icon: "flame.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }

    private func summaryTile(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)

            Text(subtext)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Watch Sensor Calibration
    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.emeraldGreen)
                Text("APPLE WATCH SENSOR CONFIG")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.emeraldGreen)
                    .tracking(1.0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hitting Wrist")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Picker("Hitting Hand", selection: $hittingHand) {
                    Text("Right Hand").tag("right")
                    Text("Left Hand").tag("left")
                }
                .pickerStyle(.segmented)
                .onChange(of: hittingHand) { _, newHand in
                    syncManager.setHittingHand(newHand)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Swing Sensitivity")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Picker("Sensitivity", selection: $swingSensitivity) {
                    Text("Low (Pro)").tag("low")
                    Text("Medium").tag("medium")
                    Text("High (Casual)").tag("high")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var deviceStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEVICE CONNECTION")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.secondary)
                .tracking(1.0)

            HStack {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(syncManager.isReachable ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch Sync")
                        .font(.headline)
                    Text(syncManager.isReachable ? "Connected & Ready for live streaming" : "Awaiting Watch foreground launch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 48))
                .foregroundColor(.emeraldGreen)
                .padding(.top, 30)

            Text("No Games Recorded Yet")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Open SwingFit on your Apple Watch and tap 'Start Match' or 'Start Rally'. Your swings, intensity, and shot distribution will appear here with AI insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Match Analysis Card View (Liquid Glass Style)
public struct MatchAnalysisCardView: View {
    @ObservedObject private var aiService = AISummaryService.shared
    
    public let match: Match
    public let matchNumber: Int
    public let isExpanded: Bool
    public let onTap: () -> Void
    public var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirmation = false

    public var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    // Match Number Badge with sport glow
                    VStack {
                        Text("M\(matchNumber)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(match.sport == .badminton ? .purple : .emeraldGreen)
                    }
                    .frame(width: 44, height: 44)
                    .background((match.sport == .badminton ? Color.purple : Color.emeraldGreen).opacity(0.15))
                    .clipShape(Circle())

                    // Swings & Date
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("\(match.totalSwings) Swings")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            if match.averageIntensity > 0 {
                                Text(String(format: "%.1f G", match.averageIntensity))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }

                            if match.sport == .badminton {
                                Text("Badminton")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                            }
                        }

                        Text(match.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Calories & Time
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(match.activeCalories)) cal")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.pink)

                        Text(formatDuration(match.duration))
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Match", systemImage: "trash")
                }
            }

            // Expanded Breakdown
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    // Shot Distribution Bars
                    Text("SHOT DISTRIBUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.0)

                    let total = max(1, match.totalSwings)
                    VStack(spacing: 8) {
                        shotRow(title: "Forehand Drive", count: match.forehandCount, total: total, color: .emeraldGreen)
                        shotRow(title: "Backhand Drive/Slice", count: match.backhandCount, total: total, color: .blue)
                        shotRow(title: "Dink (Kitchen)", count: match.dinkCount, total: total, color: .orange)
                        shotRow(title: "Overhead Smash", count: match.smashCount, total: total, color: .red)
                        if match.serveCount > 0 {
                            shotRow(title: "Serve", count: match.serveCount, total: total, color: .yellow)
                        }
                    }

                    // Swing Intensity Timeline preview
                    if let swings = match.swings, !swings.isEmpty {
                        Divider()

                        HStack {
                            Text("SWING INTENSITY TIMELINE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                            Spacer()
                            Text("\(swings.count) recorded hits")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(Array(swings.prefix(40).enumerated()), id: \.offset) { _, swing in
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(colorForSwing(swing.swingType))
                                            .frame(width: 8, height: max(6, CGFloat(swing.peakAcceleration) * 4))

                                        Text(String(format: "%.0f", swing.peakAcceleration))
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(height: 70)
                            .padding(.vertical, 4)
                        }
                    }

                    // AI Insights Button & Response
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("GEMINI AI ANALYSIS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.emeraldGreen)
                                .tracking(1.0)
                            Spacer()
                            if aiService.isGenerating(for: match.id) {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }

                        if let summary = match.aiSummary, !summary.isEmpty {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Color.emeraldGreen.opacity(0.1))
                                .cornerRadius(12)
                        } else {
                            Button {
                                aiService.generateSummary(for: match)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Analyze with Gemini AI Coach")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.emeraldGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.emeraldGreen.opacity(0.15))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(aiService.isGenerating(for: match.id))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .confirmationDialog("Delete Match #\(matchNumber)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Match", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete Match #\(matchNumber)? This will permanently remove its swing data.")
        }
    }

    private func shotRow(title: LocalizedStringKey, count: Int, total: Int, color: Color) -> some View {
        let percent = Int(Double(count) / Double(total) * 100)
        return VStack(spacing: 3) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("\(percent)% (\(count))")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(count) / CGFloat(total)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func colorForSwing(_ type: SwingType) -> Color {
        switch type {
        case .forehand: return .emeraldGreen
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

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Color {
    static let emeraldGreen = Color(red: 0.1, green: 0.78, blue: 0.45)
}
