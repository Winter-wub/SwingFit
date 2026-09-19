import XCTest
@testable import SwingFit

final class PickleballScoreTests: XCTestCase {
    func testInitialState() {
        let engine = PickleballScoreEngine()
        XCTAssertEqual(engine.state.myScore, 0)
        XCTAssertEqual(engine.state.opponentScore, 0)
        XCTAssertEqual(engine.state.servingTeam, .us)
        XCTAssertEqual(engine.state.serverNumber, 2)
        XCTAssertEqual(engine.calloutString, "0 - 0 - 2")
    }

    func testScoringByServingTeam() {
        let engine = PickleballScoreEngine()
        engine.pointScored(by: .us)
        XCTAssertEqual(engine.state.myScore, 1)
        XCTAssertEqual(engine.state.serverNumber, 2)
        XCTAssertEqual(engine.calloutString, "1 - 0 - 2")
    }

    func testFaultSwitchesFromFirstToSecondServer() {
        let engine = PickleballScoreEngine(initialState: ScoreState(myScore: 2, opponentScore: 1, servingTeam: .us, serverNumber: 1))
        engine.pointScored(by: .opponent) // fault on us
        XCTAssertEqual(engine.state.servingTeam, .us)
        XCTAssertEqual(engine.state.serverNumber, 2)
        XCTAssertEqual(engine.calloutString, "2 - 1 - 2")
    }

    func testSideOutFromSecondServer() {
        let engine = PickleballScoreEngine(initialState: ScoreState(myScore: 0, opponentScore: 0, servingTeam: .us, serverNumber: 2))
        engine.pointScored(by: .opponent) // fault on server 2
        XCTAssertEqual(engine.state.servingTeam, .opponent)
        XCTAssertEqual(engine.state.serverNumber, 1)
        XCTAssertEqual(engine.calloutString, "0 - 0 - 1")
    }

    func testUndoRestoresPreviousScore() {
        let engine = PickleballScoreEngine()
        engine.pointScored(by: .us)
        XCTAssertEqual(engine.state.myScore, 1)
        engine.undo()
        XCTAssertEqual(engine.state.myScore, 0)
    }
}
