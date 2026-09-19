import Foundation
import SwiftData

@MainActor
public final class AISummaryService: ObservableObject {
    public static let shared = AISummaryService()
    
    private let model = "nex-agi/nex-n2.5-pro:free"
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    
    @Published public var generatingMatchIds: Set<UUID> = []
    
    public static var currentLanguage: String {
        let pref = Bundle.main.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "en"
        return pref.hasPrefix("th") ? "Thai" : "English"
    }

    public static var currentLanguageCode: String {
        let pref = Bundle.main.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "en"
        return pref.hasPrefix("th") ? "th" : "en"
    }
    
    private init() {}

    private var apiKey: String? {
        Self.normalizedAPIKey(Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String)
    }

    static func normalizedAPIKey(_ rawValue: String?) -> String? {
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
        
        guard let apiKey else {
            print("AISummaryService: OPENROUTER_API_KEY is not configured; skipping summary generation.")
            return
        }

        guard !generatingMatchIds.contains(match.id) else { return }
        generatingMatchIds.insert(match.id)

        let prompt = """
        I just finished a pickleball match. Please provide a concise coaching summary in \(language) based on the following stats:
        - Duration: \(Int(match.duration / 60)) minutes
        - Calories: \(Int(match.activeCalories))
        - Average Heart Rate: \(Int(match.averageHeartRate)) bpm
        - Total Swings: \(match.totalSwings)
        - Forehands: \(match.forehandCount)
        - Backhands: \(match.backhandCount)
        - Dinks: \(match.dinkCount)
        - Smashes: \(match.smashCount)
        - Serves: \(match.serveCount)
        - Average Intensity: \(String(format: "%.1f", match.averageIntensity)) G
        - Peak Intensity: \(String(format: "%.1f", match.peakIntensity)) G
        
        Act as a professional pickleball coach. Keep it short (2-3 sentences), encouraging, and give one specific piece of advice based on the shot distribution. Do not include introductory/outro greetings, just the summary.
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: endpoint) else {
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
                        
                        // Save context using the model context from the match
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
