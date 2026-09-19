import XCTest
import SwiftData
@testable import SwingFit

private final class StubTransport: AIChatTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    var body: String
    var status: Int
    var delay: UInt64
    var onRequest: ((Int) -> Void)?

    init(body: String, status: Int = 200, delay: UInt64 = 0) {
        self.body = body
        self.status = status
        self.delay = delay
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        onRequest?(requests.count)
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

private let geminiBody = #"{"candidates":[{"content":{"parts":[{"text":" Keep your wrist firm. "}]}}]}"#
private let openRouterBody = #"{"choices":[{"message":{"content":"Split step earlier."}}]}"#

@MainActor
final class CoachTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([WorkoutSession.self, Match.self, Swing.self, CoachThread.self, CoachMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func makeMatch(complete: Bool = true) -> Match {
        let match = Match()
        match.isComplete = complete
        return match
    }

    func testFactoryPrefersGeminiThenOpenRouterThenNil() {
        XCTAssertEqual(AIProviderFactory.makeProvider(geminiAPIKey: "g", openRouterAPIKey: "o")?.1, .gemini)
        XCTAssertEqual(AIProviderFactory.makeProvider(geminiAPIKey: "$(GEMINI_API_KEY)", openRouterAPIKey: "o")?.1, .openRouter)
        XCTAssertNil(AIProviderFactory.makeProvider(geminiAPIKey: nil, openRouterAPIKey: " "))
    }

    func testGeminiProviderParsesResponse() async throws {
        let transport = StubTransport(body: geminiBody)
        let provider = GeminiChatProvider(apiKey: "k", transport: transport)
        let text = try await provider.respond(
            messages: [AIChatMessage(role: "user", content: "Help")],
            match: AIMatchContext(match: makeMatch()),
            language: "English"
        )
        XCTAssertEqual(text, "Keep your wrist firm.")
        XCTAssertTrue(transport.requests[0].url!.absoluteString.contains("generateContent"))
    }

    func testOpenRouterProviderUsesBearerAndParses() async throws {
        let transport = StubTransport(body: openRouterBody)
        let provider = OpenRouterChatProvider(apiKey: "k", transport: transport)
        let text = try await provider.respond(messages: [], match: AIMatchContext(match: makeMatch()), language: "English")
        XCTAssertEqual(text, "Split step earlier.")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer k")
    }

    func testGeminiFallsBackToSecondModelOnOverload() async throws {
        let transport = StubTransport(body: "{}", status: 503)
        transport.onRequest = { [unowned transport] count in
            if count == 2 { transport.status = 200; transport.body = geminiBody }
        }
        let provider = GeminiChatProvider(apiKey: "k", transport: transport)
        let text = try await provider.respond(messages: [], match: AIMatchContext(match: makeMatch()), language: "English")
        XCTAssertEqual(text, "Keep your wrist firm.")
        XCTAssertTrue(transport.requests[0].url!.absoluteString.contains("gemini-3.8-flash"))
        XCTAssertTrue(transport.requests[1].url!.absoluteString.contains("gemini-2.5-flash"))
    }

    func testHTTPErrorIsTyped() async {
        let provider = GeminiChatProvider(apiKey: "k", fallbackModel: nil, transport: StubTransport(body: "{}", status: 500))
        do {
            _ = try await provider.respond(messages: [], match: AIMatchContext(match: makeMatch()), language: "English")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? AIChatError, .httpError(500))
        }
    }

    func testStoreOrdersMessagesAndDeletesThread() throws {
        let store = CoachThreadStore(context: try makeContext())
        let id = UUID()
        _ = try store.createUserMessage(matchID: id, content: "one")
        _ = try store.createPendingAssistantMessage(matchID: id)
        XCTAssertEqual(try store.messages(for: id).map(\.role), [.user, .assistant])
        try store.deleteThread(for: id)
        XCTAssertTrue(try store.messages(for: id).isEmpty)
    }

    func testServiceSendPersistsUserAndAssistant() async throws {
        let service = CoachService(modelContext: try makeContext(), geminiAPIKey: "g", openRouterAPIKey: nil,
                                   transport: StubTransport(body: geminiBody))
        let match = makeMatch()
        service.select(match: match)
        await service.send("How was I?", match: match)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(service.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(service.messages.last?.status, .completed)
        XCTAssertFalse(service.isSending)
    }

    func testServiceRejectsIncompleteMatchAndMissingKey() async throws {
        let context = try makeContext()
        let keyed = CoachService(modelContext: context, geminiAPIKey: "g", openRouterAPIKey: nil,
                                 transport: StubTransport(body: geminiBody))
        await keyed.send("Hi", match: makeMatch(complete: false))
        XCTAssertTrue(keyed.messages.isEmpty)
        XCTAssertNotNil(keyed.lastError)

        let unkeyed = CoachService(modelContext: context, geminiAPIKey: "$(X)", openRouterAPIKey: "",
                                   transport: StubTransport(body: geminiBody))
        let match = makeMatch()
        unkeyed.select(match: match)
        await unkeyed.send("Hi", match: match)
        XCTAssertEqual(unkeyed.lastError, .noAPIKeyConfigured)
        XCTAssertTrue(unkeyed.messages.isEmpty)
    }

    func testFailureThenRetrySucceeds() async throws {
        let transport = StubTransport(body: "{}", status: 500)
        let service = CoachService(modelContext: try makeContext(), geminiAPIKey: "g", openRouterAPIKey: nil, transport: transport)
        let match = makeMatch()
        service.select(match: match)
        await service.send("Q", match: match)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(service.messages.last?.status, .failed)

        transport.status = 200
        transport.body = geminiBody
        await service.retry(match: match)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(service.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(service.messages.last?.status, .completed)
    }

    func testSwitchingMatchCancelsPending() async throws {
        let service = CoachService(modelContext: try makeContext(), geminiAPIKey: "g", openRouterAPIKey: nil,
                                   transport: StubTransport(body: geminiBody, delay: 500_000_000))
        let a = makeMatch(), b = makeMatch()
        service.select(match: a)
        await service.send("Q", match: a)
        service.select(match: b)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(service.messages.isEmpty)
        service.select(match: a)
        XCTAssertEqual(service.messages.map(\.role), [.user])
    }
}
