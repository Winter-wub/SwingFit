import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.startDate, order: .reverse) private var matches: [Match]
    @ObservedObject private var syncManager = WatchSyncManager.shared
    
    @AppStorage("hittingHand") private var hittingHand: String = "right"
    @AppStorage("swingSensitivity") private var swingSensitivity: String = "medium"
    
    @State private var expandedMatchId: UUID?
    @State private var showEndMatchAlert: Bool = false
    @State private var showDiscardMatchAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Match Control Card (Start from iPhone / Live Telemetry HUD)
                    matchControlCard

                    // Coach Insight Card
                    coachInsightCard

                    // Top Stat Summary Cards
                    statsSummaryGrid

                    // Watch Sensor Calibration
                    calibrationCard

                    // Section Title
                    HStack {
                        Text("Match Analysis")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(matches.count) Recorded")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("SwingFit Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        syncManager.requestSyncFromWatch()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            if syncManager.isReachable {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
            .onAppear {
                syncManager.requestSyncFromWatch()
            }
        }
    }

    // MARK: - Match Remote Control Card
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
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.emeraldGreen.opacity(0.25), Color.emeraldGreen.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "figure.pickleball")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.emeraldGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to Play?")
                        .font(.headline.bold())
                        .foregroundColor(.primary)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(syncManager.isReachable ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)

                        Text(syncManager.isReachable ? "Apple Watch Connected" : "Will launch Apple Watch")
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
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Match from iPhone")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.emeraldGreen, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.emeraldGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.emeraldGreen.opacity(0.2), lineWidth: 1)
        )
    }

    private var activeMatchHUDCard: some View {
        VStack(spacing: 16) {
            // Live Status Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncManager.isWatchMatchPaused ? Color.yellow : Color.green)
                        .frame(width: 9, height: 9)

                    Text(syncManager.isWatchMatchPaused ? "MATCH PAUSED" : "LIVE MATCH TRACKING")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(syncManager.isWatchMatchPaused ? .yellow : .green)
                        .tracking(0.5)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((syncManager.isWatchMatchPaused ? Color.yellow : Color.green).opacity(0.15))
                .cornerRadius(8)

                Spacer()

                // Live Timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                    Text(formatLiveDuration(syncManager.liveDuration))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.primary)
            }

            // 3-Column Live Telemetry
            HStack(spacing: 10) {
                // Swings Count
                VStack(spacing: 2) {
                    Text("\(syncManager.liveSwingsCount)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                    Text("SWINGS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)

                // Heart Rate
                VStack(spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(syncManager.liveHeartRate > 0 ? "\(Int(syncManager.liveHeartRate))" : "--")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                        if syncManager.liveHeartRate > 0 {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                    Text("BPM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)

                // Calories
                VStack(spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(syncManager.liveCalories > 0 ? "\(Int(syncManager.liveCalories))" : "--")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.pink)
                        if syncManager.liveCalories > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.pink)
                        }
                    }
                    Text("KCAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
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
                    .background((syncManager.isWatchMatchPaused ? Color.green : Color.yellow).opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // End Match Button
                Button {
                    showEndMatchAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                        Text("End Match")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            // Discard Match Option
            Button {
                showDiscardMatchAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Discard this match without saving")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, -4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke((syncManager.isWatchMatchPaused ? Color.yellow : Color.green).opacity(0.3), lineWidth: 1.5)
        )
    }

    private func formatLiveDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Coach Insight Card
    private var coachInsightCard: some View {
        let totalSwings = matches.reduce(0) { $0 + $1.totalSwings }
        let totalFh = matches.reduce(0) { $0 + $1.forehandCount }
        let totalBh = matches.reduce(0) { $0 + $1.backhandCount }
        let totalDinks = matches.reduce(0) { $0 + $1.dinkCount }
        let fhRatio = totalSwings > 0 ? Int(Double(totalFh) / Double(totalSwings) * 100) : 50

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text("💡")
                    .font(.system(size: 24))
                    .padding(8)
                    .background(Color.emeraldGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("COACH RECOMMENDATION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.emeraldGreen)
                            .tracking(1.0)
                        Spacer()
                        if !matches.isEmpty {
                            Text("Based on \(matches.count) matches")
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(18)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func coachAdviceContent(fhRatio: Int, totalDinks: Int) -> some View {
        if matches.isEmpty {
            Text("Start your first match on Apple Watch. SwingFit will track your strokes and power to provide personalized coaching tips.")
        } else if fhRatio > 65 {
            Text("You are heavily favoring your Forehand (\(fhRatio)%). Opponents will notice this pattern. Practice positioning earlier to take more Backhand drives and balance your court coverage.")
        } else if totalDinks > 15 {
            Text("Excellent kitchen soft game control! You hit \(totalDinks) dinks, forcing opponent resets. Keep maintaining steady wrist stability at the net.")
        } else {
            let bhRatio = 100 - fhRatio
            Text("Solid shot selection! Your Forehand (\(fhRatio)%) and Backhand (\(bhRatio)%) balance is well-rounded. Continue focusing on consistent follow-through.")
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
            // Total Swings
            summaryTile(
                title: "TOTAL SWINGS",
                value: "\(totalSwings)",
                subtext: "\(matches.count) matches total",
                icon: "waveform.path.ecg",
                color: .blue
            )

            // Shot Ratio
            summaryTile(
                title: "F / B RATIO",
                value: "\(fhPercent) / \(bhPercent)%",
                subtext: fhPercent > 55 ? "Forehand heavy" : "Balanced spread",
                icon: "arrow.left.and.right",
                color: .emeraldGreen
            )

            // Average Intensity
            summaryTile(
                title: "AVG INTENSITY",
                value: String(format: "%.1f G", overallAvgIntensity),
                subtext: "Peak: \(String(format: "%.1f G", peakIntensity))",
                icon: "bolt.fill",
                color: .orange
            )

            // Total Calories & Time
            let totalCalories = Int(matches.reduce(0) { $0 + $1.activeCalories })
            let totalTime = matches.reduce(0) { $0 + $1.duration }
            summaryTile(
                title: "WORKOUT TIME",
                value: formatDuration(totalTime),
                subtext: "\(totalCalories) cal burned",
                icon: "flame.fill",
                color: .pink
            )
        }
        .padding(.horizontal)
    }

    private func summaryTile(title: LocalizedStringKey, value: String, subtext: LocalizedStringKey, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    // MARK: - Sensor Calibration Card
    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Watch Sensor Calibration", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                Spacer()
                Text(syncManager.isReachable ? "Connected" : "Not connected")
                    .font(.caption2)
                    .foregroundColor(syncManager.isReachable ? .green : .secondary)
            }

            HStack(spacing: 12) {
                // Handedness Picker
                Picker("Wrist", selection: $hittingHand) {
                    Text("Right Hand").tag("right")
                    Text("Left Hand").tag("left")
                }
                .pickerStyle(.segmented)

                // Sensitivity
                Picker("Sensitivity", selection: $swingSensitivity) {
                    Text("Low").tag("low")
                    Text("Normal").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 52))
                .foregroundColor(.emeraldGreen)
                .padding(.top, 30)

            Text("No Matches Tracked Yet")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Open SwingFit on your Apple Watch and tap 'Start Match'. Your swings, intensity, and shot distribution will sync here automatically.")
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

// MARK: - Match Analysis Card View
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
                    // Match Number Badge
                    VStack {
                        Text("M\(matchNumber)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.emeraldGreen)
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.emeraldGreen.opacity(0.12))
                    .clipShape(Circle())

                    // Swings & Date
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("\(match.totalSwings) Swings")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
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

                        Text("SWING INTENSITY SAMPLES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)

                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(swings.prefix(28).enumerated()), id: \.offset) { _, swing in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForSwing(swing.swingType))
                                    .frame(width: 6, height: max(6, CGFloat(swing.peakAcceleration * 8)))
                            }
                        }
                        .frame(height: 48, alignment: .bottom)
                        .padding(.vertical, 4)
                    }

                    // Heart Rate Info
                    if match.averageHeartRate > 0 {
                        HStack {
                            Label("Average Heart Rate", systemImage: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)

                            Spacer()

                            Text("\(Int(match.averageHeartRate)) bpm")
                                .font(.caption.bold().monospaced())
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // AI Summary
                    Divider()
                    
                    HStack {
                        Text("COACH SUMMARY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                        
                        Spacer()
                        
                        if aiService.generatingMatchIds.contains(match.id) {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Button {
                                aiService.generateSummary(for: match, force: true)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.emeraldGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if aiService.generatingMatchIds.contains(match.id) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Generating summary...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else if let summary = match.aiSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if match.isComplete {
                        Button {
                            aiService.generateSummary(for: match, force: true)
                        } label: {
                            Label("Generate Coach Summary", systemImage: "sparkles")
                                .font(.caption.bold())
                                .foregroundColor(.emeraldGreen)
                        }
                        .buttonStyle(.plain)
                    }

                    // Delete Match Button
                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete Match")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onAppear {
                    let currentLang = AISummaryService.currentLanguageCode
                    if match.isComplete && (match.aiSummary == nil || match.aiSummaryLanguage != currentLang) {
                        aiService.generateSummary(for: match, force: true)
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .confirmationDialog("Delete Match?", isPresented: $showDeleteConfirmation) {
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

