import SwiftUI
import SwiftData

struct CoachChatView: View {
    @EnvironmentObject private var coach: CoachService
    @Query(sort: \Match.startDate, order: .reverse) private var matches: [Match]

    @State private var selectedMatchID: UUID?
    @State private var draft: String = ""
    @State private var showPicker = false
    @State private var showClearConfirm = false

    private let suggestions = [
        "What should I work on next?",
        "How was my forehand and backhand balance?",
        "Was my intensity good for this match?"
    ]

    private var completedMatches: [Match] { matches.filter { $0.isComplete } }

    private var selectedMatch: Match? {
        completedMatches.first { $0.id == selectedMatchID } ?? completedMatches.first
    }

    var body: some View {
        VStack(spacing: 12) {
            if let match = selectedMatch {
                CoachContextCardView(
                    match: match,
                    matchNumber: completedMatches.count - (completedMatches.firstIndex { $0.id == match.id } ?? 0),
                    onChange: { showPicker = true }
                )
                .padding(.horizontal)

                conversation(for: match)

                if let error = coach.lastError, error == .noAPIKeyConfigured {
                    Text(error.recoveryHint)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                } else if let error = coach.lastError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                CoachComposerView(text: $draft, isSending: coach.isSending) {
                    send(match)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else {
                emptyState
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedMatch != nil, !coach.messages.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Clear this conversation?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { coach.clearHistory() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPicker) {
            CoachMatchPickerView(
                matches: completedMatches,
                selectedID: selectedMatch?.id
            ) { match in
                selectedMatchID = match.id
                coach.select(match: match)
            }
        }
        .onAppear {
            coach.cleanupOrphanedThreads(matchIDs: Set(matches.map(\.id)))
            if coach.selectedMatchID != selectedMatch?.id {
                coach.select(match: selectedMatch)
            }
        }
        .onChange(of: completedMatches.first?.id) { _, _ in
            if selectedMatchID == nil || !completedMatches.contains(where: { $0.id == selectedMatchID }) {
                selectedMatchID = nil
                coach.select(match: selectedMatch)
            }
        }
    }

    @ViewBuilder
    private func conversation(for match: Match) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if coach.messages.isEmpty {
                        VStack(spacing: 10) {
                            Text("Ask about this match")
                                .font(.headline)
                            ForEach(suggestions, id: \.self) { prompt in
                                Button {
                                    draft = prompt
                                    send(match)
                                } label: {
                                    Text(prompt)
                                        .font(.subheadline)
                                        .foregroundColor(.emeraldGreen)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .coachGlass(cornerRadius: 14)
                                }
                                .buttonStyle(.plain)
                                .disabled(coach.isSending)
                            }
                        }
                        .padding(.top, 20)
                    }
                    ForEach(coach.messages, id: \.id) { message in
                        CoachMessageRow(message: message) {
                            Task { await coach.retry(match: match) }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: coach.messages.count) { _, _ in
                if let last = coach.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(.emeraldGreen)
            Text("No Completed Matches Yet")
                .font(.headline)
            Text("Finish a match on your Apple Watch and it will appear here so you can chat with your coach about it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send(_ match: Match) {
        let text = draft
        draft = ""
        Task { await coach.send(text, match: match) }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
