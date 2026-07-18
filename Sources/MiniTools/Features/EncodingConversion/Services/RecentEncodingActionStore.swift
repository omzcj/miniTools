import Foundation

final class RecentEncodingActionStore {
    private static let defaultsKey = "encodingConversion.recentActionIDs"
    private static let storageLimit = 20

    private let defaults: UserDefaults?
    private(set) var actionIDs: [String]

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        actionIDs = defaults?.stringArray(forKey: Self.defaultsKey) ?? []
    }

    func record(_ actionID: String) {
        actionIDs.removeAll(where: { $0 == actionID })
        actionIDs.insert(actionID, at: 0)
        actionIDs = Array(actionIDs.prefix(Self.storageLimit))
        defaults?.set(actionIDs, forKey: Self.defaultsKey)
    }
}
