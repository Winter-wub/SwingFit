import Foundation
import Combine

public enum Team: String, Codable {
    case us = "US"
    case opponent = "THEM"

    public static var them: Team { .opponent }
}

public struct ScoreState: Codable, Equatable {
    public var myScore: Int
    public var opponentScore: Int
    public var servingTeam: Team
    public var serverNumber: Int

    public init(myScore: Int = 0, opponentScore: Int = 0, servingTeam: Team = .us, serverNumber: Int = 2) {
        self.myScore = myScore
        self.opponentScore = opponentScore
        self.servingTeam = servingTeam
        self.serverNumber = serverNumber
    }
}

public typealias PickleballMatch = PickleballScoreEngine

public final class PickleballScoreEngine: ObservableObject {
    @Published public var state: ScoreState
    private var history: [ScoreState] = []

    public init(initialState: ScoreState = ScoreState()) {
        self.state = initialState
    }

    public var myScore: Int { state.myScore }
    public var opponentScore: Int { state.opponentScore }
    public var servingTeam: Team { state.servingTeam }
    public var serverNumber: Int { state.serverNumber }

    public func scorePoint(scoringTeam: Team) {
        pointScored(by: scoringTeam)
    }

    public func resetGame() {
        reset()
    }

    public var calloutString: String {
        let servingScore = (state.servingTeam == .us) ? state.myScore : state.opponentScore
        let receivingScore = (state.servingTeam == .us) ? state.opponentScore : state.myScore
        return "\(servingScore) - \(receivingScore) - \(state.serverNumber)"
    }

    public func pointScored(by team: Team) {
        saveHistory()
        if team == state.servingTeam {
            // Serving team scored a point; they keep serving
            if team == .us {
                state.myScore += 1
            } else {
                state.opponentScore += 1
            }
        } else {
            // Receiving team won rally -> Fault on serving team!
            handleFault()
        }
    }

    public func manualIncrement(for team: Team) {
        saveHistory()
        if team == .us {
            state.myScore += 1
        } else {
            state.opponentScore += 1
        }
    }

    public func sideOut() {
        saveHistory()
        handleFault()
    }

    public func toggleServingTeam() {
        saveHistory()
        state.servingTeam = (state.servingTeam == .us) ? .opponent : .us
    }

    public func toggleServerNumber() {
        saveHistory()
        state.serverNumber = (state.serverNumber == 1) ? 2 : 1
    }

    public func undo() {
        guard let previous = history.popLast() else { return }
        state = previous
    }

    public func reset() {
        saveHistory()
        state = ScoreState(myScore: 0, opponentScore: 0, servingTeam: .us, serverNumber: 2)
    }

    private func handleFault() {
        if state.serverNumber == 1 {
            // Move to second server
            state.serverNumber = 2
        } else {
            // Side out: Turn over serve to other team, reset to server 1
            state.serverNumber = 1
            state.servingTeam = (state.servingTeam == .us) ? .opponent : .us
        }
    }

    private func saveHistory() {
        history.append(state)
        if history.count > 30 {
            history.removeFirst()
        }
    }
}
