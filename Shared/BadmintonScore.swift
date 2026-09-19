import Foundation

public enum ServiceCourt: String, Codable {
    case right = "Right (Even)"
    case left = "Left (Odd)"
}

public struct BadmintonScoreState: Codable, Equatable {
    public var myScore: Int
    public var opponentScore: Int
    public var servingTeam: Team
    
    public init(myScore: Int = 0, opponentScore: Int = 0, servingTeam: Team = .us) {
        self.myScore = myScore
        self.opponentScore = opponentScore
        self.servingTeam = servingTeam
    }
    
    /// BWF Rule: Even score serves from Right court; Odd score serves from Left court.
    public var currentServiceCourt: ServiceCourt {
        let serverScore = (servingTeam == .us) ? myScore : opponentScore
        return (serverScore % 2 == 0) ? .right : .left
    }
    
    /// Target is 21 points, must lead by 2, capped at 30 points.
    public var isGameOver: Bool {
        let maxScore = max(myScore, opponentScore)
        let minScore = min(myScore, opponentScore)
        if maxScore >= 30 { return true }
        if maxScore >= 21 && (maxScore - minScore) >= 2 { return true }
        return false
    }
    
    public var winningTeam: Team? {
        guard isGameOver else { return nil }
        return (myScore > opponentScore) ? .us : .opponent
    }
}

public final class BadmintonScoreEngine: ObservableObject {
    @Published public var state: BadmintonScoreState
    private var history: [BadmintonScoreState] = []

    public init(initialState: BadmintonScoreState = BadmintonScoreState()) {
        self.state = initialState
    }

    public var calloutString: String {
        return "\(state.myScore) - \(state.opponentScore)"
    }

    /// In BWF rally point scoring, every rally awards a point.
    /// The side that wins the rally scores a point and serves the next point.
    public func pointScored(by team: Team) {
        saveHistory()
        if team == .us {
            state.myScore += 1
        } else {
            state.opponentScore += 1
        }
        state.servingTeam = team
    }

    public func manualIncrement(for team: Team) {
        saveHistory()
        if team == .us {
            state.myScore += 1
        } else {
            state.opponentScore += 1
        }
    }

    public func toggleServingTeam() {
        saveHistory()
        state.servingTeam = (state.servingTeam == .us) ? .opponent : .us
    }

    public func undo() {
        guard let previous = history.popLast() else { return }
        state = previous
    }

    public func reset() {
        saveHistory()
        state = BadmintonScoreState(myScore: 0, opponentScore: 0, servingTeam: .us)
    }

    private func saveHistory() {
        history.append(state)
        if history.count > 40 {
            history.removeFirst()
        }
    }
}
