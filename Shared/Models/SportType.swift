import Foundation

public enum SportType: String, Codable, CaseIterable {
    case pickleball = "Pickleball"
    case badminton = "Badminton"
    
    public var targetScore: Int {
        switch self {
        case .pickleball:
            return 11
        case .badminton:
            return 21
        }
    }
    
    public var maxScoreCap: Int? {
        switch self {
        case .pickleball:
            return nil
        case .badminton:
            return 30
        }
    }
}
