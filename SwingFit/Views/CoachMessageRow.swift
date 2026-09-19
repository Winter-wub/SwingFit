import SwiftUI

extension View {
    func coachGlass(cornerRadius: CGFloat = 20, tint: Color = .white) -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct CoachMessageRow: View {
    let message: CoachMessage
    let onRetry: () -> Void

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                bubble
                if message.status == .failed {
                    HStack(spacing: 8) {
                        Label(message.errorText ?? "Something went wrong.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Button("Retry", action: onRetry)
                            .font(.caption.bold())
                            .foregroundColor(.emeraldGreen)
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        if message.status == .pending {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Coach is thinking…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .coachGlass(cornerRadius: 18)
        } else if message.role == .user {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.black)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color.emeraldGreen, Color(red: 0.2, green: 0.9, blue: 0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(14)
                .coachGlass(cornerRadius: 18)
        }
    }
}
