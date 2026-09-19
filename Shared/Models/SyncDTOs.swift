import Foundation

public struct SwingDTO: Codable {
    public let id: UUID
    public let timestamp: Date
    public let swingTypeRaw: String
    public let peakAcceleration: Double

    public init(id: UUID, timestamp: Date, swingTypeRaw: String, peakAcceleration: Double) {
        self.id = id
        self.timestamp = timestamp
        self.swingTypeRaw = swingTypeRaw
        self.peakAcceleration = peakAcceleration
    }

    public init(from swing: Swing) {
        self.id = swing.id
        self.timestamp = swing.timestamp
        self.swingTypeRaw = swing.swingTypeRaw
        self.peakAcceleration = swing.peakAcceleration
    }
}

public struct MatchDTO: Codable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let myScore: Int
    public let opponentScore: Int
    public let activeCalories: Double
    public let averageHeartRate: Double
    public let duration: TimeInterval
    public let isComplete: Bool
    public let aiSummary: String?
    public let aiSummaryLanguage: String?
    public let swings: [SwingDTO]

    public init(from match: Match) {
        self.id = match.id
        self.startDate = match.startDate
        self.endDate = match.endDate
        self.myScore = match.myScore
        self.opponentScore = match.opponentScore
        self.activeCalories = match.activeCalories
        self.averageHeartRate = match.averageHeartRate
        self.duration = match.duration
        self.isComplete = match.isComplete
        self.aiSummary = match.aiSummary
        self.aiSummaryLanguage = match.aiSummaryLanguage
        self.swings = (match.swings ?? []).map { SwingDTO(from: $0) }
    }
}

public struct SessionDTO: Codable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let totalCalories: Double
    public let averageHeartRate: Double
    public let totalDuration: TimeInterval
    public let isComplete: Bool
    public let matches: [MatchDTO]

    public init(from session: WorkoutSession) {
        self.id = session.id
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.totalCalories = session.totalCalories
        self.averageHeartRate = session.averageHeartRate
        self.totalDuration = session.totalDuration
        self.isComplete = session.isComplete
        self.matches = (session.matches ?? []).map { MatchDTO(from: $0) }
    }
}
