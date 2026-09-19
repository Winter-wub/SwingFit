import Foundation

public protocol AIChatTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionChatTransport: AIChatTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

public protocol AIChatProviding: Sendable {
    var providerType: AIProviderType { get }
    func respond(messages: [AIChatMessage], match: AIMatchContext, language: String) async throws -> String
}

public final class GeminiChatProvider: AIChatProviding {
    public let providerType: AIProviderType = .gemini

    private let apiKey: String
    private let model: String
    private let fallbackModel: String?
    private let transport: AIChatTransport

    public init(
        apiKey: String,
        model: String = "gemini-3.8-flash",
        fallbackModel: String? = "gemini-2.5-flash",
        transport: AIChatTransport = URLSessionChatTransport()
    ) {
        self.apiKey = apiKey
        self.model = model
        self.fallbackModel = fallbackModel
        self.transport = transport
    }

    public func respond(messages: [AIChatMessage], match: AIMatchContext, language: String) async throws -> String {
        do {
            return try await respond(using: model, messages: messages, match: match, language: language)
        } catch AIChatError.httpError(let status) where [429, 500, 503].contains(status) {
            guard let fallbackModel else { throw AIChatError.httpError(status) }
            return try await respond(using: fallbackModel, messages: messages, match: match, language: language)
        }
    }

    private func respond(using model: String, messages: [AIChatMessage], match: AIMatchContext, language: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw AIChatError.invalidURL
        }

        let history = messages.map { message in
            "\(message.role.capitalized): \(message.content)"
        }.joined(separator: "\n\n")
        let matchDetails = CoachPromptFormatter.matchDetails(match)
        let prompt = """
        \(CoachPromptFormatter.systemInstruction(language: language, provider: .gemini))

        \(history)

        \(matchDetails)

        Answer the latest user question in \(language). Keep the response concise (2-3 sentences), encouraging, and include one specific tactical or biomechanical recommendation based on the match data. Do not include a greeting or mention that you are an AI.
        """
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIChatError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIChatError.httpError(httpResponse.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIChatError.emptyResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public final class OpenRouterChatProvider: AIChatProviding {
    public let providerType: AIProviderType = .openRouter

    private let apiKey: String
    private let model: String
    private let transport: AIChatTransport

    public init(apiKey: String, model: String = "nex-agi/nex-n2.5-pro:free", transport: AIChatTransport = URLSessionChatTransport()) {
        self.apiKey = apiKey
        self.model = model
        self.transport = transport
    }

    public func respond(messages: [AIChatMessage], match: AIMatchContext, language: String) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AIChatError.invalidURL
        }

        let matchDetails = CoachPromptFormatter.matchDetails(match)
        let systemMessage = AIChatMessage(role: "system", content: CoachPromptFormatter.systemInstruction(language: language, provider: .openRouter))
        let requestMessages = ([systemMessage] + messages + [
            AIChatMessage(role: "user", content: """
            Use the selected match context below to answer the latest user question in \(language). Keep the response concise (2-3 sentences), encouraging, and include one specific tactical or biomechanical recommendation based on the match data. Do not include a greeting or mention that you are an AI.

            \(matchDetails)
            """)
        ]).map { ["role": $0.role, "content": $0.content] }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": requestMessages,
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("https://github.com/prachayawut/SwingFit", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("SwingFit App", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIChatError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIChatError.httpError(httpResponse.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIChatError.emptyResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum AIProviderFactory {
    public static func makeProvider(
        geminiAPIKey: String?,
        openRouterAPIKey: String?,
        transport: AIChatTransport = URLSessionChatTransport()
    ) -> (AIChatProviding, AIProviderType)? {
        if let apiKey = AISummaryService.normalizedAPIKey(geminiAPIKey) {
            return (GeminiChatProvider(apiKey: apiKey, transport: transport), .gemini)
        }
        if let apiKey = AISummaryService.normalizedAPIKey(openRouterAPIKey) {
            return (OpenRouterChatProvider(apiKey: apiKey, transport: transport), .openRouter)
        }
        return nil
    }
}

public enum CoachPromptFormatter {
    public static func systemInstruction(language: String, provider: AIProviderType) -> String {
        "You are SwingFit's \(provider.displayString)-powered pickleball and badminton coach. Respond in \(language). Use only the supplied match data and conversation. Prefer one concrete, safe, actionable recommendation."
    }

    public static func matchDetails(_ match: AIMatchContext) -> String {
        let result = match.isWin ? "won \(match.myScore)-\(match.opponentScore)" : "lost \(match.myScore)-\(match.opponentScore)"
        let shots = match.shotCounts.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }.joined(separator: "\n")
        return """
        Match context:
        - Sport: \(match.sport)
        - Result: \(result)
        - Duration: \(Int(match.duration / 60)) minutes
        - Active calories: \(Int(match.activeCalories))
        - Average heart rate: \(Int(match.averageHeartRate)) bpm
        - Total swings: \(match.totalSwings)
        - Average intensity: \(String(format: "%.1f", match.averageIntensity)) G
        - Peak intensity: \(String(format: "%.1f", match.peakIntensity)) G
        Shot counts:
        \(shots.isEmpty ? "- None recorded" : shots)
        """
    }
}
