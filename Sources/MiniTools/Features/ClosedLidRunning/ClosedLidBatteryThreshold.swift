import Foundation

enum ClosedLidBatteryThreshold: Int, CaseIterable, Identifiable, Sendable {
    case ten = 10
    case twenty = 20
    case thirty = 30
    case forty = 40
    case fifty = 50

    var id: Self { self }

    var title: String {
        "\(rawValue)%"
    }
}
