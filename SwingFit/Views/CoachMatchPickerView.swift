import SwiftUI

struct CoachMatchPickerView: View {
    let matches: [Match]
    let selectedID: UUID?
    let onSelect: (Match) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    Button {
                        onSelect(match)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("M\(matches.count - index) · \(match.totalSwings) swings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(match.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if match.id == selectedID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.emeraldGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
