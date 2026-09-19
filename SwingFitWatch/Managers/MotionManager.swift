import Foundation
import CoreMotion

public struct MotionSample {
    public let timestamp: TimeInterval
    public let accelX: Double
    public let accelY: Double
    public let accelZ: Double
    public let gyroX: Double
    public let gyroY: Double
    public let gyroZ: Double
}

@MainActor
public final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var recordedSamples: [MotionSample] = []
    
    @Published public var isTracking = false
    @Published public var detectedSwingsCount = 0
    @Published public var lastDetectedType: SwingType = .unknown
    @Published public var lastAcceleration: Double = 0.0
    @Published public var hittingHand: String = UserDefaults.standard.string(forKey: "hittingHand") ?? "right"
    @Published public var sensitivity: String = UserDefaults.standard.string(forKey: "swingSensitivity") ?? "medium"
    @Published public var sport: SportType = .pickleball
    
    public var onSwingDetected: ((SwingType, Double) -> Void)?

    private var cooldownCounter = 0
    private let swingCooldownFrames = 25 // ~0.5 second at 50Hz

    public init() {}

    public func setHittingHand(_ hand: String) {
        hittingHand = hand
        UserDefaults.standard.set(hand, forKey: "hittingHand")
    }

    public func setSensitivity(_ level: String) {
        sensitivity = level
        UserDefaults.standard.set(level, forKey: "swingSensitivity")
    }

    public func simulateSwing(type: SwingType, intensity: Double = 3.0) {
        detectedSwingsCount += 1
        lastDetectedType = type
        lastAcceleration = intensity
        onSwingDetected?(type, intensity)
    }

    public func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available on this device")
            return
        }

        recordedSamples.removeAll()
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
        isTracking = true
    }

    public func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        isTracking = false
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        let sample = MotionSample(
            timestamp: motion.timestamp,
            accelX: motion.userAcceleration.x,
            accelY: motion.userAcceleration.y,
            accelZ: motion.userAcceleration.z,
            gyroX: motion.rotationRate.x,
            gyroY: motion.rotationRate.y,
            gyroZ: motion.rotationRate.z
        )
        recordedSamples.append(sample)

        if cooldownCounter > 0 {
            cooldownCounter -= 1
            return
        }

        // Calculate acceleration magnitude (G-forces)
        let totalAcceleration = sqrt(
            pow(sample.accelX, 2) +
            pow(sample.accelY, 2) +
            pow(sample.accelZ, 2)
        )

        // Threshold based on sensitivity
        let threshold: Double
        switch sensitivity.lowercased() {
        case "high":
            threshold = 1.6
        case "low":
            threshold = 3.2
        default: // medium
            threshold = 2.2
        }

        if totalAcceleration > threshold {
            // Invert gyro rotation if watch is worn on left hand
            let rotationZ = (hittingHand.lowercased() == "left") ? -sample.gyroZ : sample.gyroZ

            let detectedType: SwingType
            if sport == .badminton {
                if totalAcceleration > 5.5 {
                    detectedType = .smash
                } else if totalAcceleration > 3.8 {
                    detectedType = .clear
                } else if totalAcceleration < 2.0 && abs(rotationZ) < 0.9 {
                    detectedType = .netShot
                } else if totalAcceleration < 2.5 && abs(sample.accelY) > 1.2 {
                    detectedType = .dropShot
                } else if abs(rotationZ) > 1.8 {
                    detectedType = .drive
                } else if rotationZ > 1.0 {
                    detectedType = .forehand
                } else if rotationZ < -1.0 {
                    detectedType = .backhand
                } else {
                    detectedType = .serve
                }
            } else {
                if totalAcceleration > 4.2 {
                    detectedType = .smash
                } else if totalAcceleration < 2.0 && abs(rotationZ) < 1.0 {
                    detectedType = .dink
                } else if rotationZ > 1.2 {
                    detectedType = .forehand
                } else if rotationZ < -1.2 {
                    detectedType = .backhand
                } else {
                    detectedType = .serve
                }
            }

            detectedSwingsCount += 1
            lastDetectedType = detectedType
            lastAcceleration = totalAcceleration
            cooldownCounter = swingCooldownFrames
            onSwingDetected?(detectedType, totalAcceleration)
        }
    }

    public func exportCSV() -> URL? {
        let fileName = "PickleballMotion_\(Int(Date().timeIntervalSince1970)).csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        var csvText = "timestamp,accelX,accelY,accelZ,gyroX,gyroY,gyroZ\n"
        for s in recordedSamples {
            csvText += String(format: "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", s.timestamp, s.accelX, s.accelY, s.accelZ, s.gyroX, s.gyroY, s.gyroZ)
        }

        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }
}
