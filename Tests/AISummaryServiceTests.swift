import XCTest
@testable import SwingFit

@MainActor
final class AISummaryServiceTests: XCTestCase {
    func testNormalizedAPIKeyTrimsWhitespace() {
        XCTAssertEqual(
            AISummaryService.normalizedAPIKey("  sk-or-v1-test-key  \n"),
            "sk-or-v1-test-key"
        )
    }

    func testNormalizedAPIKeyRejectsMissingAndUnresolvedValues() {
        XCTAssertNil(AISummaryService.normalizedAPIKey(nil))
        XCTAssertNil(AISummaryService.normalizedAPIKey("   \n"))
        XCTAssertNil(AISummaryService.normalizedAPIKey("$(OPENROUTER_API_KEY)"))
    }
}
