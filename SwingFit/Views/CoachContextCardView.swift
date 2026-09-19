import SwiftUI

struct CoachContextCardView: View {
    let match: Match
    let matchNumber: Int
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("M\(matchNumber)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("COACHING ON")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.0)
                    .foregroundColor(.emeraldGreen)
                Text("\(match.totalSwings) swings · \(Int(match.duration / 60)) min · \(match.myScore)-\(match.opponentScore)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(match.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Change", action: onChange)
                .font(.subheadline.bold())
                .foregroundColor(.emeraldGreen)
        }
        .padding(16)
        .coachGlass()
    }

    private var accent: Color {
        match.sport == .badminton ? .purple : .emeraldGreen
    }
}
