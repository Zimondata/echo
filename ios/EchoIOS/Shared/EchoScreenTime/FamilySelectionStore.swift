import FamilyControls
import Foundation

public struct FamilySelectionStore {
    private let defaults: UserDefaults

    public init(suiteName: String = EchoAppGroup.identifier) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw EchoSharedStoreError.appGroupUnavailable(suiteName)
        }
        self.defaults = defaults
    }

    public func save(_ selection: FamilyActivitySelection) throws {
        defaults.set(try PropertyListEncoder().encode(selection), forKey: EchoAppGroup.familySelectionKey)
    }

    public func load() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: EchoAppGroup.familySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }
}
