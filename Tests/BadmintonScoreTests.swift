import XCTest
@testable import SwingFit

final class BadmintonScoreTests: XCTestCase {
    func testInitialState() {
        let engine = BadmintonScoreEngine()
        XCTAssertEqual(engine.state.myScore, 0)
        XCTAssertEqual(engine.state.opponentScore, 0)
        XCTAssertEqual(engine.state.servingTeam, .us)
        XCTAssertEqual(engine.state.currentServiceCourt, .right)
        XCTAssertEqual(engine.calloutString, "0 - 0")
        XCTAssertFalse(engine.state.isGameOver)
    }

    func testRallyPointScoring() {
        let engine = BadmintonScoreEngine()
        engine.pointScored(by: .us)
        XCTAssertEqual(engine.state.myScore, 1)
        XCTAssertEqual(engine.state.opponentScore, 0)
        XCTAssertEqual(engine.state.servingTeam, .us)
        XCTAssertEqual(engine.state.currentServiceCourt, .left) // 1 is odd -> Left court

        engine.pointScored(by: .opponent)
        XCTAssertEqual(engine.state.myScore, 1)
        XCTAssertEqual(engine.state.opponentScore, 1)
        XCTAssertEqual(engine.state.servingTeam, .opponent)
        XCTAssertEqual(engine.state.currentServiceCourt, .left) // 1 is odd -> Left court
    }

    func testDeuceWinByTwo() {
        let state = BadmintonScoreState(myScore: 20, opponentScore: 20, servingTeam: .us)
        let engine = BadmintonScoreEngine(initialState: state)
        XCTAssertFalse(engine.state.isGameOver)

        engine.pointScored(by: .us) // 21 - 20 (not over, must lead by 2)
        XCTAssertFalse(engine.state.isGameOver)

        engine.pointScored(by: .us) // 22 - 20 (win!)
        XCTAssertTrue(engine.state.isGameOver)
        XCTAssertEqual(engine.state.winningTeam, .us)
    }

    func testGoldenPointCapAt30() {
        let state = BadmintonScoreState(myScore: 29, opponentScore: 29, servingTeam: .opponent)
        let engine = BadmintonScoreEngine(initialState: state)
        XCTAssertFalse(engine.state.isGameOver)

        engine.pointScored(by: .opponent) // 30 - 29 (sudden death cap reached)
        XCTAssertTrue(engine.state.isGameOver)
        XCTAssertEqual(engine.state.winningTeam, .opponent)
    }

    func testUndo() {
        let engine = BadmintonScoreEngine()
        engine.pointScored(by: .us)
        XCTAssertEqual(engine.state.myScore, 1)
        engine.undo()
        XCTAssertEqual(engine.state.myScore, 0)
    }
}
