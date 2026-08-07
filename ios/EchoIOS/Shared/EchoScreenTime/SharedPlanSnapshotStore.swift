import Foundation
import EchoCore

public struct SharedPlanSnapshotStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init?(suiteName: String = EchoAppGroup.identifier) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ snapshot: PlanSnapshot) throws {
        defaults.set(try encoder.encode(snapshot), forKey: EchoAppGroup.planSnapshotKey)
    }

    public func load() -> PlanSnapshot? {
        guard let data = defaults.data(forKey: EchoAppGroup.planSnapshotKey) else { return nil }
        return try? decoder.decode(PlanSnapshot.self, from: data)
    }
}
