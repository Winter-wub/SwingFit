import Foundation
import SwiftData

@Model
public final class Match {
    public var id: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date?
    public var myScore: Int = 0
    public var opponentScore: Int = 0
    public var activeCalories: Double = 0.0
    public var averageHeartRate: Double = 0.0
    public var duration: TimeInterval = 0.0
    public var isComplete: Bool = false
    public var aiSummary: String? = nil
    public var aiSummaryLanguage: String? = nil
    public var sportRaw: String = SportType.pickleball.rawValue

    public var sport: SportType {
        get { SportType(rawValue: sportRaw) ?? .pickleball }
        set { sportRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Swing.match)
    public var swings: [Swing]? = []

    public var session: WorkoutSession?

    public var isWin: Bool {
        return myScore > opponentScore
    }

    public var forehandCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .forehand }.count
    }

    public var backhandCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .backhand }.count
    }

    public var dinkCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .dink }.count
    }

    public var smashCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .smash }.count
    }

    public var serveCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .serve }.count
    }

    public var clearCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .clear }.count
    }

    public var dropShotCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .dropShot }.count
    }

    public var driveCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .drive }.count
    }

    public var netShotCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .netShot }.count
    }

    public var liftCount: Int {
        guard let swings = swings else { return 0 }
        return swings.filter { $0.swingType == .lift }.count
    }

    public var totalSwings: Int {
        return (swings ?? []).count
    }

    public var averageIntensity: Double {
        guard let swings = swings, !swings.isEmpty else { return 0.0 }
        let total = swings.reduce(0.0) { $0 + $1.peakAcceleration }
        return total / Double(swings.count)
    }

    public var peakIntensity: Double {
        guard let swings = swings, !swings.isEmpty else { return 0.0 }
        return swings.map { $0.peakAcceleration }.max() ?? 0.0
    }

    public init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        myScore: Int = 0,
        opponentScore: Int = 0,
        activeCalories: Double = 0.0,
        averageHeartRate: Double = 0.0,
        duration: TimeInterval = 0.0,
        isComplete: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.myScore = myScore
        self.opponentScore = opponentScore
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.duration = duration
        self.isComplete = isComplete
        self.swings = []
    }
}
