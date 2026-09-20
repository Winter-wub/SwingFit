import SwiftUI

/// Setup screen shown before starting a live court session.
/// User selects Sport + Wrist, then launches Watch tracking.
public struct CourtSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var syncManager = WatchSyncManager.shared

    @AppStorage("lastSport") private var lastSport: String = SportType.pickleball.rawValue
    @AppStorage("hittingHand") private var hittingHand: String = "right"

    @State private var selectedSport: SportType = .pickleball
    @State private var showWatchAlert = false

    public init() {}

    public var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            // Ambient glow
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

            ScrollView {
                VStack(spacing: 22) {
                    // Sport Selector
                    sportSection

                    // Wrist Selector
                    wristSection

                    Spacer(minLength: 20)

                    // Start Button
                    startButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
        }
        .navigationTitle("Court Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedSport = SportType(rawValue: lastSport) ?? .pickleball
        }
        .onChange(of: selectedSport) { _, newSport in
            lastSport = newSport.rawValue
        }
        .alert("Watch Not Connected", isPresented: $showWatchAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure your Apple Watch is nearby and SwingFit is running on it.")
        }
    }

    // MARK: - Sport Section
    private var sportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sportscourt")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.emeraldGreen)
                Text("SPORT")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.emeraldGreen)
                    .tracking(1.0)
            }

            HStack(spacing: 10) {
                sportCard(
                    sport: .pickleball,
                    icon: "figure.pickleball",
                    title: "Pickleball",
                    tint: .green
                )
                sportCard(
                    sport: .badminton,
                    icon: "figure.badminton",
                    title: "Badminton",
                    tint: .purple
                )
            }
        }
    }

    private func sportCard(sport: SportType, icon: String, title: String, tint: Color) -> some View {
        Button {
            selectedSport = sport
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.35), tint.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedSport == sport ? tint.opacity(0.6) : tint.opacity(0.2),
                                    lineWidth: selectedSport == sport ? 2 : 1
                                )
                        )

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(tint)
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                if selectedSport == sport {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        selectedSport == sport
                            ? tint.opacity(0.5)
                            : Color.white.opacity(0.15),
                        lineWidth: selectedSport == sport ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wrist Section
    private var wristSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
                Text("WATCH WRIST")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.yellow)
                    .tracking(1.0)
            }

            HStack(spacing: 10) {
                wristCard(hand: "left", icon: "hand.raised.left.fill", title: "Left")
                wristCard(hand: "right", icon: "hand.raised.right.fill", title: "Right")
            }
        }
    }

    private func wristCard(hand: String, icon: String, title: String) -> some View {
        Button {
            hittingHand = hand
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(hittingHand == hand ? .yellow : .secondary)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                if hittingHand == hand {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        hittingHand == hand
                            ? Color.yellow.opacity(0.5)
                            : Color.white.opacity(0.15),
                        lineWidth: hittingHand == hand ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button {
            guard syncManager.isReachable else {
                showWatchAlert = true
                return
            }
            syncManager.startMatchFromPhone(
                sport: selectedSport,
                hittingHand: hittingHand
            )
            dismiss()
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .heavy))
                    Text("START COURT SESSION")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }

                Text("\(selectedSport.rawValue) • \(hittingHand.capitalized) Wrist")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.emeraldGreen, Color(red: 0.2, green: 0.9, blue: 0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(18)
            .shadow(color: Color.emeraldGreen.opacity(0.35), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!syncManager.isReachable)
        .opacity(syncManager.isReachable ? 1 : 0.5)
    }
}
