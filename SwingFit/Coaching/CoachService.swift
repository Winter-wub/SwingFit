import Foundation
import SwiftData
import Combine

@MainActor
public final class CoachService: ObservableObject {
    @Published public private(set) var messages: [CoachMessage] = []
    @Published public private(set) var isSending: Bool = false
    @Published public var lastError: AIChatError?
    @Published public private(set) var selectedMatchID: UUID?
    @Published public private(set) var selectedProviderType: AIProviderType?

    private let store: CoachThreadStore
    private var provider: AIChatProviding?
    private var task: Task<Void, Never>?
    private var requestID: Int = 0

    public init(
        modelContext: ModelContext,
        geminiAPIKey: String? = nil,
        openRouterAPIKey: String? = nil,
        transport: AIChatTransport = URLSessionChatTransport()
    ) {
        let normalizedGeminiKey = AISummaryService.normalizedAPIKey(geminiAPIKey ?? AISummaryService.shared.geminiAPIKey)
        let normalizedOpenRouterKey = AISummaryService.normalizedAPIKey(openRouterAPIKey ?? AISummaryService.shared.openRouterAPIKey)
        let providerResult = Self.makeProvider(
            geminiAPIKey: normalizedGeminiKey,
            openRouterAPIKey: normalizedOpenRouterKey,
            transport: transport
        )

        self.store = CoachThreadStore(context: modelContext)
        self.provider = providerResult?.provider
        self.selectedProviderType = providerResult?.type
    }

    public func select(match: Match?) {
        let previousMatchID = selectedMatchID
        requestID += 1
        task?.cancel()
        task = nil
        isSending = false
        lastError = nil
        selectedMatchID = match?.id

        if let previousMatchID, previousMatchID != match?.id {
            try? store.deletePendingAssistantMessages(matchID: previousMatchID)
        }

        if let match {
            do {
                messages = try store.messages(for: match.id)
            } catch {
                messages = []
                lastError = .underlying(error.localizedDescription)
            }
        } else {
            messages = []
        }
    }

    public func send(_ content: String, match: Match) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        guard match.isComplete else {
            lastError = .underlying("Coach chat is available for completed matches only.")
            return
        }
        guard !isSending else { return }
        guard provider != nil else {
            lastError = .noAPIKeyConfigured
            return
        }

        do {
            _ = try store.createUserMessage(matchID: match.id, content: trimmedContent)
            await request(content: trimmedContent, match: match)
        } catch let error as AIChatError {
            lastError = error
        } catch {
            lastError = .underlying(error.localizedDescription)
        }
    }

    public func retry(match: Match) async {
        guard !isSending else { return }
        guard provider != nil else {
            lastError = .noAPIKeyConfigured
            return
        }
        guard let failedIndex = messages.lastIndex(where: { $0.status == .failed }) else { return }
        guard let userMessage = messages[..<failedIndex].last(where: { $0.role == .user }) else { return }

        do {
            try store.deleteMessage(messages[failedIndex])
            messages = try store.messages(for: match.id)
            await request(content: userMessage.content, match: match)
        } catch let error as AIChatError {
            lastError = error
        } catch {
            lastError = .underlying(error.localizedDescription)
        }
    }

    public func cancelInFlight() {
        requestID += 1
        task?.cancel()
        task = nil
        isSending = false
        lastError = nil

        if let selectedMatchID {
            try? store.deletePendingAssistantMessages(matchID: selectedMatchID)
            messages = (try? store.messages(for: selectedMatchID)) ?? []
        }
    }

    public func clearHistory() {
        requestID += 1
        task?.cancel()
        task = nil
        isSending = false
        lastError = nil

        guard let selectedMatchID else {
            messages = []
            return
        }

        do {
            try store.deleteThread(for: selectedMatchID)
            messages = []
        } catch {
            lastError = .underlying(error.localizedDescription)
        }
    }

    public func cleanupOrphanedThreads(matchIDs: Set<UUID>) {
        do {
            try store.cleanupOrphanedThreads(matchIDs: matchIDs)
        } catch {
            lastError = .underlying(error.localizedDescription)
        }
    }

    public static func makeProvider(
        geminiAPIKey: String?,
        openRouterAPIKey: String?,
        transport: AIChatTransport = URLSessionChatTransport()
    ) -> (provider: AIChatProviding, type: AIProviderType)? {
        AIProviderFactory.makeProvider(
            geminiAPIKey: geminiAPIKey,
            openRouterAPIKey: openRouterAPIKey,
            transport: transport
        )
    }

    private func request(content: String, match: Match) async {
        requestID += 1
        let currentRequestID = requestID
        selectedMatchID = match.id
        isSending = true
        lastError = nil

        guard let provider else {
            isSending = false
            lastError = .noAPIKeyConfigured
            return
        }

        do {
            let assistantMessage = try store.createPendingAssistantMessage(matchID: match.id)
            messages = try store.messages(for: match.id)

            let history = messages
                .filter { $0.status == .completed }
                .suffix(8)
                .map { AIChatMessage(role: $0.role.rawValue, content: $0.content) }

            task = Task { [weak self] in
                guard let self else { return }

                do {
                    let response = try await provider.respond(
                        messages: history,
                        match: AIMatchContext(match: match),
                        language: AISummaryService.currentLanguage
                    )

                    await MainActor.run {
                        guard currentRequestID == self.requestID, self.selectedMatchID == match.id else {
                            try? self.store.deleteMessage(assistantMessage)
                            return
                        }

                        do {
                            try self.store.completeAssistantMessage(assistantMessage, content: response)
                            self.messages = (try? self.store.messages(for: match.id)) ?? self.messages
                            self.isSending = false
                            self.lastError = nil
                        } catch {
                            try? self.store.failAssistantMessage(assistantMessage, error: error)
                            self.messages = (try? self.store.messages(for: match.id)) ?? self.messages
                            self.isSending = false
                            self.lastError = .underlying(error.localizedDescription)
                        }
                        if self.requestID == currentRequestID {
                            self.task = nil
                        }
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        guard currentRequestID == self.requestID, self.selectedMatchID == match.id else {
                            try? self.store.deleteMessage(assistantMessage)
                            return
                        }
                        try? self.store.deleteMessage(assistantMessage)
                        self.messages = (try? self.store.messages(for: match.id)) ?? self.messages
                        self.isSending = false
                        self.lastError = nil
                        self.task = nil
                    }
                } catch let error as AIChatError {
                    await MainActor.run {
                        guard currentRequestID == self.requestID, self.selectedMatchID == match.id else {
                            try? self.store.deleteMessage(assistantMessage)
                            return
                        }
                        try? self.store.failAssistantMessage(assistantMessage, error: error)
                        self.messages = (try? self.store.messages(for: match.id)) ?? self.messages
                        self.isSending = false
                        self.lastError = error
                        self.task = nil
                    }
                } catch {
                    await MainActor.run {
                        guard currentRequestID == self.requestID, self.selectedMatchID == match.id else {
                            try? self.store.deleteMessage(assistantMessage)
                            return
                        }
                        try? self.store.failAssistantMessage(assistantMessage, error: error)
                        self.messages = (try? self.store.messages(for: match.id)) ?? self.messages
                        self.isSending = false
                        self.lastError = .underlying(error.localizedDescription)
                        self.task = nil
                    }
                }
            }
        } catch let error as AIChatError {
            isSending = false
            lastError = error
        } catch {
            isSending = false
            lastError = .underlying(error.localizedDescription)
        }
    }

}
