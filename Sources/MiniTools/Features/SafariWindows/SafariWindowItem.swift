import Foundation

struct SafariWindowItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let wasActiveWindow: Bool
    let hasTabGroup: Bool
}
