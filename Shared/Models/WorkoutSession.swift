import Foundation
import SwiftData

@Model
public final class WorkoutSession {
    public var id: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date?
    public var totalCalories: Double = 0.0
    public var averageHeartRate: Double = 0.0
    public var totalDuration: TimeInterval = 0.0
    public var isComplete: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Match.session)
    public var matches: [Match]? = []

    public var totalSwings: Int {
        guard let matches = matches else { return 0 }
        return matches.reduce(0) { $0 + $1.totalSwings }
    }

    public var totalWins: Int {
        guard let matches = matches else { return 0 }
        return matches.filter { $0.isWin }.count
    }

    public init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        totalCalories: Double = 0.0,
        averageHeartRate: Double = 0.0,
        totalDuration: TimeInterval = 0.0,
        isComplete: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.totalDuration = totalDuration
        self.isComplete = isComplete
        self.matches = []
    }
}
