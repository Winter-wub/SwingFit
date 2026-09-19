import Foundation
import SwiftData

@MainActor
public final class CoachThreadStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func thread(for matchID: UUID) throws -> CoachThread? {
        let descriptor = FetchDescriptor<CoachThread>(
            predicate: #Predicate<CoachThread> { $0.matchID == matchID },
            sortBy: [SortDescriptor(\CoachThread.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    public func messages(for matchID: UUID) throws -> [CoachMessage] {
        let descriptor = FetchDescriptor<CoachMessage>(
            predicate: #Predicate<CoachMessage> { $0.thread?.matchID == matchID },
            sortBy: [
                SortDescriptor(\CoachMessage.createdAt),
                SortDescriptor(\CoachMessage.id)
            ]
        )
        return try context.fetch(descriptor)
    }

    public func createUserMessage(matchID: UUID, content: String) throws -> CoachMessage {
        let thread = try existingOrNewThread(for: matchID)
        let message = CoachMessage(role: .user, content: content, thread: thread)
        context.insert(message)
        try context.save()
        return message
    }

    public func createPendingAssistantMessage(matchID: UUID) throws -> CoachMessage {
        let thread = try existingOrNewThread(for: matchID)
        let message = CoachMessage(role: .assistant, content: "Thinking…", status: .pending, thread: thread)
        context.insert(message)
        try context.save()
        return message
    }

    public func completeAssistantMessage(_ message: CoachMessage, content: String) throws {
        message.content = content
        message.status = .completed
        message.errorText = nil
        try context.save()
    }

    public func failAssistantMessage(_ message: CoachMessage, error: Error) throws {
        message.status = .failed
        message.errorText = error.localizedDescription
        try context.save()
    }

    public func deleteThread(for matchID: UUID) throws {
        guard let thread = try thread(for: matchID) else { return }
        context.delete(thread)
        try context.save()
    }

    public func deleteThread(_ thread: CoachThread) throws {
        context.delete(thread)
        try context.save()
    }

    public func deleteMessage(_ message: CoachMessage) throws {
        context.delete(message)
        try context.save()
    }

    public func deletePendingAssistantMessages(matchID: UUID) throws {
        let assistantRaw = CoachMessageRole.assistant.rawValue
        let pendingRaw = CoachMessageStatus.pending.rawValue
        let descriptor = FetchDescriptor<CoachMessage>(
            predicate: #Predicate<CoachMessage> {
                $0.thread?.matchID == matchID &&
                $0.roleRaw == assistantRaw &&
                $0.statusRaw == pendingRaw
            }
        )
        let pendingMessages = try context.fetch(descriptor)
        pendingMessages.forEach { context.delete($0) }
        if !pendingMessages.isEmpty {
            try context.save()
        }
    }

    public func cleanupOrphanedThreads(matchIDs: Set<UUID>) throws {
        let descriptor = FetchDescriptor<CoachThread>()
        let threads = try context.fetch(descriptor)
        let orphanedThreads = threads.filter { !matchIDs.contains($0.matchID) }
        orphanedThreads.forEach { context.delete($0) }
        if !orphanedThreads.isEmpty {
            try context.save()
        }
    }

    private func existingOrNewThread(for matchID: UUID) throws -> CoachThread {
        if let thread = try thread(for: matchID) {
            return thread
        }
        let thread = CoachThread(matchID: matchID)
        context.insert(thread)
        try context.save()
        return thread
    }
}
