import Foundation

enum ClosedLidRunDuration: String, CaseIterable, Codable, Identifiable, Sendable {
    case unlimited
    case oneHour
    case twoHours
    case fourHours
    case eightHours

    static let menuCases: [Self] = [
        .unlimited,
        .oneHour,
        .twoHours,
        .fourHours,
        .eightHours
    ]

    var id: Self { self }

    var title: String {
        switch self {
        case .unlimited: "不限时"
        case .oneHour: "1 小时"
        case .twoHours: "2 小时"
        case .fourHours: "4 小时"
        case .eightHours: "8 小时"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .unlimited: nil
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        case .fourHours: 4 * 60 * 60
        case .eightHours: 8 * 60 * 60
        }
    }
}
