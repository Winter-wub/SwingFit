import Foundation
import SwiftData

public enum CoachMessageRole: String, Codable, CaseIterable {
    case user
    case assistant
}

public enum CoachMessageStatus: String, Codable, CaseIterable {
    case completed
    case pending
    case failed
}

@Model
public final class CoachThread {
    public var id: UUID = UUID()
    public var matchID: UUID
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CoachMessage.thread)
    public var messages: [CoachMessage]? = []

    public init(matchID: UUID, createdAt: Date = Date()) {
        self.matchID = matchID
        self.createdAt = createdAt
        self.messages = []
    }
}

@Model
public final class CoachMessage {
    public var id: UUID = UUID()
    public var roleRaw: String = CoachMessageRole.user.rawValue
    public var content: String
    public var createdAt: Date = Date()
    public var statusRaw: String = CoachMessageStatus.completed.rawValue
    public var errorText: String?

    public var thread: CoachThread?

    public var role: CoachMessageRole {
        get { CoachMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    public var status: CoachMessageStatus {
        get { CoachMessageStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        content: String,
        createdAt: Date = Date(),
        status: CoachMessageStatus = .completed,
        errorText: String? = nil,
        thread: CoachThread? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = createdAt
        self.statusRaw = status.rawValue
        self.errorText = errorText
        self.thread = thread
    }
}
