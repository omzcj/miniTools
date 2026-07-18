import Foundation

enum MouseGestureConfiguration {
    static let defaultDragThresholdRatio: Double = 0.02
    static let dragThresholdRatioRange: ClosedRange<Double> = 0.005...0.1
    static let dragThresholdRatioStep: Double = 0.005
    static let legacyReferenceScreenWidth: Double = 1_200

    static func normalizedDragThresholdRatio(_ value: Double) -> Double {
        guard value.isFinite else { return defaultDragThresholdRatio }
        return min(
            max(value, dragThresholdRatioRange.lowerBound),
            dragThresholdRatioRange.upperBound
        )
    }
}

enum MouseSideButton: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    // Core Graphics numbers buttons from zero. Physical Button 4/5 are therefore 3/4.
    case button4 = 3
    case button5 = 4

    var id: Self { self }

    var title: String {
        switch self {
        case .button4: "Button 4"
        case .button5: "Button 5"
        }
    }

    init?(eventButtonNumber: Int64) {
        self.init(rawValue: Int(eventButtonNumber))
    }
}

enum MouseButtonGesture: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case singleClick
    case doubleClick
    case dragUp
    case dragDown
    case dragLeft
    case dragRight

    var id: Self { self }

    var title: String {
        switch self {
        case .singleClick: "单击"
        case .doubleClick: "双击"
        case .dragUp: "向上拖动"
        case .dragDown: "向下拖动"
        case .dragLeft: "向左拖动"
        case .dragRight: "向右拖动"
        }
    }

    var systemImage: String {
        switch self {
        case .singleClick: "cursorarrow.click"
        case .doubleClick: "cursorarrow.click.2"
        case .dragUp: "arrow.up"
        case .dragDown: "arrow.down"
        case .dragLeft: "arrow.left"
        case .dragRight: "arrow.right"
        }
    }

    var dragDirection: MouseDragDirection? {
        switch self {
        case .singleClick, .doubleClick: nil
        case .dragUp: .up
        case .dragDown: .down
        case .dragLeft: .left
        case .dragRight: .right
        }
    }

    static let clickGestures: [Self] = [.singleClick, .doubleClick]
    static let dragGestures: [Self] = [.dragUp, .dragDown, .dragLeft, .dragRight]
}

enum MouseDragDirection: String, CaseIterable, Codable, Hashable, Sendable {
    case up
    case down
    case left
    case right

    var gesture: MouseButtonGesture {
        switch self {
        case .up: .dragUp
        case .down: .dragDown
        case .left: .dragLeft
        case .right: .dragRight
        }
    }

    var systemImage: String {
        gesture.systemImage
    }
}

struct MouseBindingKey: Codable, Hashable, Sendable {
    let button: MouseSideButton
    let gesture: MouseButtonGesture
}

struct MouseBinding: Codable, Hashable, Sendable {
    let button: MouseSideButton
    let gesture: MouseButtonGesture
    let command: AppCommand

    var key: MouseBindingKey {
        MouseBindingKey(button: button, gesture: gesture)
    }
}
