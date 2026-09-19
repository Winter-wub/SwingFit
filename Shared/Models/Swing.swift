import Foundation
import SwiftData

public enum SwingType: String, Codable, CaseIterable {
    case forehand = "Forehand"
    case backhand = "Backhand"
    case dink = "Dink"
    case smash = "Overhead Smash"
    case serve = "Serve"
    // Badminton-specific strokes
    case clear = "Clear"
    case dropShot = "Drop Shot"
    case drive = "Drive"
    case netShot = "Net Shot"
    case lift = "Lift"
    case unknown = "Unknown"
}

@Model
public final class Swing {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var swingTypeRaw: String = SwingType.unknown.rawValue
    public var peakAcceleration: Double = 0.0
    public var match: Match?

    public var swingType: SwingType {
        get { SwingType(rawValue: swingTypeRaw) ?? .unknown }
        set { swingTypeRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), swingType: SwingType = .unknown, peakAcceleration: Double = 0.0) {
        self.id = id
        self.timestamp = timestamp
        self.swingTypeRaw = swingType.rawValue
        self.peakAcceleration = peakAcceleration
    }
}
