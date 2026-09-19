import Foundation
import Combine
import SwiftData

@MainActor
public final class AISummaryService: ObservableObject {
    public static let shared = AISummaryService()
    
    // Gemini 2.5/3 Flash API endpoint
    private let geminiModel = "gemini-3.8-flash"
    private let openRouterModel = "nex-agi/nex-n2.5-pro:free"
    private let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"
    
    @Published public var generatingMatchIds: Set<UUID> = []
    
    public var isGenerating: Bool {
        !generatingMatchIds.isEmpty
    }

    public func isGenerating(for matchId: UUID) -> Bool {
        generatingMatchIds.contains(matchId)
    }
    
    public static var currentLanguage: String {
        let pref = Bundle.main.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "en"
        return pref.hasPrefix("th") ? "Thai" : "English"
    }

    public static var currentLanguageCode: String {
        let pref = Bundle.main.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "en"
        return pref.hasPrefix("th") ? "th" : "en"
    }
    
    private init() {}

    public var geminiAPIKey: String? {
        Self.normalizedAPIKey(Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String)
    }

    public var openRouterAPIKey: String? {
        Self.normalizedAPIKey(Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String)
    }

    public static func normalizedAPIKey(_ rawValue: String?) -> String? {
        let key = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty, !key.hasPrefix("$(") else {
            return nil
        }
        return key
    }

    public func generateSummary(for match: Match, force: Bool = false) {
        guard match.isComplete else { return }
        
        let language = Self.currentLanguage
        let langCode = Self.currentLanguageCode
        
        if !force && match.aiSummary != nil && match.aiSummaryLanguage == langCode {
            return
        }
        
        guard let apiKey = geminiAPIKey ?? openRouterAPIKey else {
            print("AISummaryService: Neither GEMINI_API_KEY nor OPENROUTER_API_KEY is configured; skipping summary generation.")
            return
        }

        guard !generatingMatchIds.contains(match.id) else { return }
        generatingMatchIds.insert(match.id)

        let isGemini = (geminiAPIKey != nil)
        let isBadminton = (match.sport == .badminton)
        let sportName = isBadminton ? "Badminton" : "Pickleball"

        let shotDetails: String
        if isBadminton {
            shotDetails = """
            - Smashes: \(match.smashCount)
            - Clears / Lobs: \(match.clearCount)
            - Drop Shots: \(match.dropShotCount)
            - Fast Drives: \(match.driveCount)
            - Net Shots / Kills: \(match.netShotCount)
            - Serves: \(match.serveCount)
            - Forehands: \(match.forehandCount)
            - Backhands: \(match.backhandCount)
            """
        } else {
            shotDetails = """
            - Forehands: \(match.forehandCount)
            - Backhands: \(match.backhandCount)
            - Dinks: \(match.dinkCount)
            - Smashes: \(match.smashCount)
            - Serves: \(match.serveCount)
            """
        }

        let prompt = """
        I just finished a \(sportName) match. Please provide a concise coaching summary in \(language) based on the following stats:
        - Sport: \(sportName)
        - Duration: \(Int(match.duration / 60)) minutes
        - Calories: \(Int(match.activeCalories))
        - Average Heart Rate: \(Int(match.averageHeartRate)) bpm
        - Total Swings: \(match.totalSwings)
        \(shotDetails)
        - Average Intensity: \(String(format: "%.1f", match.averageIntensity)) G
        - Peak Intensity: \(String(format: "%.1f", match.peakIntensity)) G
        
        Act as an elite, world-class \(sportName) coach powered by Google Gemini. Keep it short (2-3 sentences), encouraging, and give one specific biomechanical or tactical piece of advice based on the shot distribution and acceleration data. Do not include introductory/outro greetings, just the summary.
        """

        if isGemini {
            callGeminiAPI(apiKey: apiKey, prompt: prompt, match: match, langCode: langCode)
        } else {
            callOpenRouterAPI(apiKey: apiKey, prompt: prompt, match: match, langCode: langCode)
        }
    }

    private func callGeminiAPI(apiKey: String, prompt: String, match: Match, langCode: String) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            generatingMatchIds.remove(match.id)
            return
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("AISummaryService: Failed to serialize Gemini request body.")
            generatingMatchIds.remove(match.id)
            return
        }

        Task {
            defer {
                generatingMatchIds.remove(match.id)
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let contentObj = firstCandidate["content"] as? [String: Any],
                       let parts = contentObj["parts"] as? [[String: Any]],
                       let text = parts.first?["text"] as? String {
                        
                        match.aiSummary = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        match.aiSummaryLanguage = langCode
                        
                        if let context = match.modelContext {
                            try? context.save()
                            print("AISummaryService [Gemini]: Saved summary (\(langCode)) for match \(match.id).")
                        }
                    }
                } else {
                    print("AISummaryService [Gemini]: HTTP Error \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                    if let errorStr = String(data: data, encoding: .utf8) {
                        print("AISummaryService [Gemini]: Response: \(errorStr)")
                    }
                }
            } catch {
                print("AISummaryService [Gemini]: Network error: \(error)")
            }
        }
    }

    private func callOpenRouterAPI(apiKey: String, prompt: String, match: Match, langCode: String) {
        let requestBody: [String: Any] = [
            "model": openRouterModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: openRouterEndpoint) else {
            generatingMatchIds.remove(match.id)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("https://github.com/prachayawut/SwingFit", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("SwingFit App", forHTTPHeaderField: "X-Title")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("AISummaryService: Failed to serialize request body.")
            generatingMatchIds.remove(match.id)
            return
        }
        
        Task {
            defer {
                generatingMatchIds.remove(match.id)
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        match.aiSummary = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        match.aiSummaryLanguage = langCode
                        
                        if let context = match.modelContext {
                            try? context.save()
                            print("AISummaryService: Saved summary (\(langCode)) for match \(match.id).")
                        }
                    }
                } else {
                    print("AISummaryService: HTTP Error \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                    if let errorStr = String(data: data, encoding: .utf8) {
                        print("AISummaryService: Response: \(errorStr)")
                    }
                }
            } catch {
                print("AISummaryService: Network error: \(error)")
            }
        }
    }
}
