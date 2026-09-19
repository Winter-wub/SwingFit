import Foundation

public enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini
    case openRouter
}

public struct AIChatMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIMatchContext: Codable, Sendable {
    public let sport: String
    public let duration: TimeInterval
    public let activeCalories: Double
    public let averageHeartRate: Double
    public let totalSwings: Int
    public let averageIntensity: Double
    public let peakIntensity: Double
    public let isWin: Bool
    public let myScore: Int
    public let opponentScore: Int
    public let shotCounts: [String: Int]

    public init(
        sport: String,
        duration: TimeInterval,
        activeCalories: Double,
        averageHeartRate: Double,
        totalSwings: Int,
        averageIntensity: Double,
        peakIntensity: Double,
        isWin: Bool,
        myScore: Int,
        opponentScore: Int,
        shotCounts: [String: Int]
    ) {
        self.sport = sport
        self.duration = duration
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.totalSwings = totalSwings
        self.averageIntensity = averageIntensity
        self.peakIntensity = peakIntensity
        self.isWin = isWin
        self.myScore = myScore
        self.opponentScore = opponentScore
        self.shotCounts = shotCounts
    }

    public init(match: Match) {
        var shotCounts: [String: Int] = [
            "Forehand": match.forehandCount,
            "Backhand": match.backhandCount,
            "Dink": match.dinkCount,
            "Smash": match.smashCount,
            "Serve": match.serveCount,
            "Clear": match.clearCount,
            "Drop shot": match.dropShotCount,
            "Drive": match.driveCount,
            "Net shot": match.netShotCount,
            "Lift": match.liftCount
        ]
        shotCounts = shotCounts.filter { $0.value > 0 }

        self.init(
            sport: match.sport.rawValue,
            duration: match.duration,
            activeCalories: match.activeCalories,
            averageHeartRate: match.averageHeartRate,
            totalSwings: match.totalSwings,
            averageIntensity: match.averageIntensity,
            peakIntensity: match.peakIntensity,
            isWin: match.isWin,
            myScore: match.myScore,
            opponentScore: match.opponentScore,
            shotCounts: shotCounts
        )
    }
}

public enum AIChatError: Error, LocalizedError, Equatable, Sendable {
    case missingAPIKey(AIProviderType)
    case noAPIKeyConfigured
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpError(Int)
    case cancelled
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No \(provider.displayString) API key is configured."
        case .noAPIKeyConfigured:
            return "No AI provider API key is configured."
        case .invalidURL:
            return "The AI provider URL could not be created."
        case .invalidResponse:
            return "The AI provider returned an unexpected response."
        case .emptyResponse:
            return "The AI provider returned no coach response."
        case .httpError(let statusCode):
            return "The AI provider request failed with status \(statusCode)."
        case .cancelled:
            return "The coach request was cancelled."
        case .underlying(let message):
            return message
        }
    }

    public var recoveryHint: String {
        switch self {
        case .missingAPIKey, .noAPIKeyConfigured:
            return "Add a provider key to the Debug secrets configuration, then reopen the Coach."
        case .httpError:
            return "Check your network connection and provider configuration, then try again."
        case .cancelled:
            return "Try sending the question again."
        default:
            return "Try again. If the problem continues, check your network connection."
        }
    }
}

public extension AIProviderType {
    var displayString: String {
        switch self {
        case .gemini: return "Gemini"
        case .openRouter: return "OpenRouter"
        }
    }
}
