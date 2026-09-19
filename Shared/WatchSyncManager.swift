import Foundation
import WatchConnectivity
import SwiftData

#if os(iOS)
import HealthKit
#endif

@MainActor
public final class WatchSyncManager: NSObject, ObservableObject {
    public static let shared = WatchSyncManager()

    public var modelContext: ModelContext?

    @Published public var isReachable: Bool = false
    @Published public var lastSyncDate: Date?

    // Live match state received from Apple Watch
    @Published public var isWatchMatchRunning: Bool = false
    @Published public var isWatchMatchPaused: Bool = false
    @Published public var liveSwingsCount: Int = 0
    @Published public var liveDuration: TimeInterval = 0.0
    @Published public var liveHeartRate: Double = 0.0
    @Published public var liveCalories: Double = 0.0

    public var pendingCommand: String?
    public var onCommandReceived: ((String) -> Void)? {
        didSet {
            if let pending = pendingCommand, let handler = onCommandReceived {
                pendingCommand = nil
                handler(pending)
            }
        }
    }

    public func triggerCommand(_ command: String) {
        if let handler = onCommandReceived {
            handler(command)
        } else {
            pendingCommand = command
        }
    }

    // MARK: - Deletion Tombstones & Sync
    private let deletedMatchIdsKey = "deletedMatchIds"
    public var deletedMatchIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: deletedMatchIdsKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: deletedMatchIdsKey)
        }
    }

    public func isMatchDeleted(_ id: UUID) -> Bool {
        deletedMatchIds.contains(id.uuidString)
    }

    public func recordMatchDeleted(_ id: UUID) {
        var set = deletedMatchIds
        set.insert(id.uuidString)
        deletedMatchIds = set
    }

    public func deleteMatch(id: UUID) {
        recordMatchDeleted(id)
        purgeMatchLocally(id)
        sendMatchDeletion(id)
    }

    public func sendMatchDeletion(_ id: UUID) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "deleteMatchId": id.uuidString,
            "deletedMatchIds": Array(deletedMatchIds)
        ]

        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("WatchSyncManager sendMatchDeletion sendMessage error: \(error.localizedDescription)")
            }
        }
        print("WatchSyncManager: Dispatched match deletion for \(id)")
    }

    public func purgeMatchLocally(_ id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.id == id })
        if let match = try? context.fetch(descriptor).first {
            if let session = match.session {
                session.matches?.removeAll(where: { $0.id == id })
            }
            context.delete(match)
            try? context.save()
            print("WatchSyncManager: Purged match \(id) locally")
        }
    }

    public func purgeDeletedMatchesLocally() {
        guard let context = modelContext else { return }
        let deletedSet = deletedMatchIds
        guard !deletedSet.isEmpty else { return }

        let descriptor = FetchDescriptor<Match>()
        if let matches = try? context.fetch(descriptor) {
            var didDelete = false
            for match in matches {
                if deletedSet.contains(match.id.uuidString) {
                    if let session = match.session {
                        session.matches?.removeAll(where: { $0.id == match.id })
                    }
                    context.delete(match)
                    didDelete = true
                }
            }
            if didDelete {
                try? context.save()
                print("WatchSyncManager: Purged deleted matches from local database")
            }
        }
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Remote Control Commands
    #if os(iOS)
    public func startMatchFromPhone() {
        if HKHealthStore.isHealthDataAvailable() {
            let healthStore = HKHealthStore()
            let config = HKWorkoutConfiguration()
            config.activityType = .pickleball
            config.locationType = .outdoor

            healthStore.startWatchApp(with: config) { success, error in
                if let error = error {
                    print("WatchSyncManager startWatchApp error: \(error.localizedDescription)")
                } else {
                    print("WatchSyncManager startWatchApp launched successfully: \(success)")
                }
            }
        }

        sendCommandToWatch("startMatch")
        isWatchMatchRunning = true
        isWatchMatchPaused = false
        liveSwingsCount = 0
        liveDuration = 0
    }
    #endif

    public func sendCommandToWatch(_ command: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = ["command": command]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("sendCommandToWatch error: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(payload)
        }

        if command == "endMatch" || command == "discardMatch" {
            isWatchMatchRunning = false
            isWatchMatchPaused = false
        } else if command == "pauseMatch" {
            isWatchMatchPaused = true
        } else if command == "resumeMatch" {
            isWatchMatchPaused = false
        }
    }

    #if os(watchOS)
    public func sendMatchStateToPhone(
        isRunning: Bool,
        isPaused: Bool,
        swingsCount: Int,
        elapsedTime: TimeInterval,
        heartRate: Double,
        calories: Double
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let stateDict: [String: Any] = [
            "isRunning": isRunning,
            "isPaused": isPaused,
            "swingsCount": swingsCount,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "calories": calories
        ]
        let payload: [String: Any] = ["matchState": stateDict]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(payload)
        }
    }
    #endif

    // MARK: - Sending from Watch
    public func sendMatch(_ match: Match) {
        if isMatchDeleted(match.id) {
            print("WatchSyncManager: Skipping sending deleted match \(match.id)")
            return
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let dto = MatchDTO(from: match)
        do {
            let data = try JSONEncoder().encode(dto)
            let payload: [String: Any] = ["match": data]

            // Always queue guaranteed background transfer
            session.transferUserInfo(payload)

            // If phone is awake and reachable, also send instant message
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { error in
                    print("WatchSyncManager instant sendMessage error: \(error.localizedDescription)")
                }
            }
            print("WatchSyncManager: queued match \(match.id) for sync to iPhone")
        } catch {
            print("WatchSyncManager encode error: \(error)")
        }
    }

    public func sendSession(_ workoutSession: WorkoutSession) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if let matches = workoutSession.matches {
            workoutSession.matches = matches.filter { !isMatchDeleted($0.id) }
        }

        let dto = SessionDTO(from: workoutSession)
        do {
            let data = try JSONEncoder().encode(dto)
            let payload: [String: Any] = ["session": data]

            session.transferUserInfo(payload)

            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { error in
                    print("WatchSyncManager instant sendMessage error: \(error.localizedDescription)")
                }
            }
            print("WatchSyncManager: queued session \(workoutSession.id) for sync to iPhone")
        } catch {
            print("WatchSyncManager encode error: \(error)")
        }
    }

    // MARK: - Request Sync from iPhone
    public func requestSyncFromWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = ["requestSync": true]
        let currentDeleted = Array(deletedMatchIds)
        if !currentDeleted.isEmpty {
            payload["deletedMatchIds"] = currentDeleted
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Ingestion
    public func processPayload(_ dict: [String: Any]) {
        // Handle command (e.g. startMatch, endMatch, pauseMatch, resumeMatch, discardMatch)
        if let command = dict["command"] as? String {
            print("WatchSyncManager received command: \(command)")
            triggerCommand(command)
            return
        }

        // Handle live match state (from Watch to iOS)
        if let matchState = dict["matchState"] as? [String: Any] {
            self.isWatchMatchRunning = matchState["isRunning"] as? Bool ?? false
            self.isWatchMatchPaused = matchState["isPaused"] as? Bool ?? false
            self.liveSwingsCount = matchState["swingsCount"] as? Int ?? 0
            self.liveDuration = matchState["elapsedTime"] as? TimeInterval ?? 0.0
            self.liveHeartRate = matchState["heartRate"] as? Double ?? 0.0
            self.liveCalories = matchState["calories"] as? Double ?? 0.0
            return
        }

        // Handle deleted match sync
        if let deletedIds = dict["deletedMatchIds"] as? [String] {
            var current = deletedMatchIds
            for idStr in deletedIds {
                current.insert(idStr)
            }
            deletedMatchIds = current
            purgeDeletedMatchesLocally()
        }

        if let deleteIdStr = dict["deleteMatchId"] as? String, let uuid = UUID(uuidString: deleteIdStr) {
            recordMatchDeleted(uuid)
            purgeMatchLocally(uuid)
            return
        }

        guard let context = modelContext else {
            print("WatchSyncManager: modelContext is nil, cannot ingest payload")
            return
        }

        // Handle Request Sync on Watch
        if let isRequest = dict["requestSync"] as? Bool, isRequest {
            handleSyncRequestOnWatch()
            return
        }

        // Handle Match payload
        if let matchData = dict["match"] as? Data {
            do {
                let dto = try JSONDecoder().decode(MatchDTO.self, from: matchData)
                ingestMatchDTO(dto, into: context)
                lastSyncDate = Date()
            } catch {
                print("WatchSyncManager decode MatchDTO error: \(error)")
            }
        }

        // Handle Session payload
        if let sessionData = dict["session"] as? Data {
            do {
                let dto = try JSONDecoder().decode(SessionDTO.self, from: sessionData)
                ingestSessionDTO(dto, into: context)
                lastSyncDate = Date()
            } catch {
                print("WatchSyncManager decode SessionDTO error: \(error)")
            }
        }
    }

    private func ingestMatchDTO(_ dto: MatchDTO, into context: ModelContext) {
        if isMatchDeleted(dto.id) {
            print("WatchSyncManager: Rejecting incoming match \(dto.id) because it is marked as deleted")
            return
        }

        let matchId = dto.id
        let descriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.id == matchId })

        let match: Match
        if let existing = try? context.fetch(descriptor).first {
            match = existing
        } else {
            match = Match(id: dto.id)
            context.insert(match)
        }

        match.startDate = dto.startDate
        match.endDate = dto.endDate
        match.myScore = dto.myScore
        match.opponentScore = dto.opponentScore
        match.activeCalories = dto.activeCalories
        match.averageHeartRate = dto.averageHeartRate
        match.duration = dto.duration
        match.isComplete = dto.isComplete

        // Sync swings
        let existingSwingIds = Set((match.swings ?? []).map { $0.id })
        for swingDTO in dto.swings {
            if !existingSwingIds.contains(swingDTO.id) {
                let swing = Swing(
                    id: swingDTO.id,
                    timestamp: swingDTO.timestamp,
                    swingType: SwingType(rawValue: swingDTO.swingTypeRaw) ?? .unknown,
                    peakAcceleration: swingDTO.peakAcceleration
                )
                swing.match = match
                context.insert(swing)
                match.swings?.append(swing)
            }
        }

        do {
            try context.save()
            print("WatchSyncManager: successfully saved match \(match.id) with \(match.totalSwings) swings")
            
            #if os(iOS)
            // Coach summaries are generated by the iPhone companion app.
            if match.isComplete && match.aiSummary == nil {
                Task { @MainActor in
                    AISummaryService.shared.generateSummary(for: match)
                }
            }
            #endif
        } catch {
            print("WatchSyncManager: save match failed: \(error)")
        }
    }

    private func ingestSessionDTO(_ dto: SessionDTO, into context: ModelContext) {
        let sessionId = dto.id
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionId })

        let session: WorkoutSession
        if let existing = try? context.fetch(descriptor).first {
            session = existing
        } else {
            session = WorkoutSession(id: dto.id)
            context.insert(session)
        }

        session.startDate = dto.startDate
        session.endDate = dto.endDate
        session.totalCalories = dto.totalCalories
        session.averageHeartRate = dto.averageHeartRate
        session.totalDuration = dto.totalDuration
        session.isComplete = dto.isComplete

        for matchDTO in dto.matches {
            if isMatchDeleted(matchDTO.id) {
                continue
            }
            ingestMatchDTO(matchDTO, into: context)
            let matchDescriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.id == matchDTO.id })
            if let match = try? context.fetch(matchDescriptor).first {
                match.session = session
                if !(session.matches ?? []).contains(where: { $0.id == match.id }) {
                    session.matches?.append(match)
                }
            }
        }

        do {
            try context.save()
            print("WatchSyncManager: successfully saved session \(session.id)")
        } catch {
            print("WatchSyncManager: save session failed: \(error)")
        }
    }

    private func handleSyncRequestOnWatch() {
        guard let context = modelContext else { return }
        purgeDeletedMatchesLocally()

        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let sessions = try? context.fetch(descriptor) {
            for session in sessions {
                sendSession(session)
            }
        }

        let matchDescriptor = FetchDescriptor<Match>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let matches = try? context.fetch(matchDescriptor) {
            for match in matches {
                if !isMatchDeleted(match.id) {
                    sendMatch(match)
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSyncManager: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            print("WCSession activated: \(activationState.rawValue), isReachable: \(session.isReachable)")
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            print("WCSession reachability changed: \(session.isReachable)")
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            self.processPayload(userInfo)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.processPayload(message)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.processPayload(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
