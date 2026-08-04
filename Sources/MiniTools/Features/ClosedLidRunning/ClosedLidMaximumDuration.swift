import Foundation

enum ClosedLidMaximumDuration: String, CaseIterable, Codable, Identifiable {
    case twoHours
    case fourHours
    case eightHours
    case twelveHours
    case unlimited

    var id: Self { self }

    var title: String {
        switch self {
        case .twoHours: "2 小时"
        case .fourHours: "4 小时"
        case .eightHours: "8 小时"
        case .twelveHours: "12 小时"
        case .unlimited: "不限时"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .twoHours: 2 * 60 * 60
        case .fourHours: 4 * 60 * 60
        case .eightHours: 8 * 60 * 60
        case .twelveHours: 12 * 60 * 60
        case .unlimited: nil
        }
    }
}
