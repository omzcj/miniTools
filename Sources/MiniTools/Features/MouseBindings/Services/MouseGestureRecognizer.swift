import CoreGraphics
import Foundation

enum MouseButtonEventPhase: Equatable, Sendable {
    case down
    case dragged
    case up
}

struct MouseButtonEvent: Sendable {
    let button: MouseSideButton
    let phase: MouseButtonEventPhase
    let location: CGPoint
    let timestamp: TimeInterval
}

enum MouseGestureRecognition: Equatable, Sendable {
    case gesture(MouseSideButton, MouseButtonGesture)
    case dragPreview(MouseSideButton, MouseDragDirection, CGPoint, CGPoint)
    case dismissDragPreview(MouseSideButton)
    case scheduleSingleClick(MouseSideButton, UUID, TimeInterval)
    case cancelSingleClick(MouseSideButton, UUID)
}

struct MouseGestureRecognizer {
    static let maximumClickDuration: TimeInterval = 0.7
    static let referenceScreenSize = CGSize(width: 1_200, height: 800)

    private struct PressState {
        let location: CGPoint
        let timestamp: TimeInterval
        let screenSize: CGSize
        var dragDirection: MouseDragDirection?
    }

    private struct PendingClick {
        let token: UUID
        let timestamp: TimeInterval
    }

    private var presses: [MouseSideButton: PressState] = [:]
    private var pendingClicks: [MouseSideButton: PendingClick] = [:]

    mutating func handle(
        _ event: MouseButtonEvent,
        supportsDoubleClick: Bool,
        doubleClickInterval: TimeInterval,
        dragThresholdRatio: Double = MouseGestureConfiguration.defaultDragThresholdRatio,
        screenSize: CGSize = Self.referenceScreenSize
    ) -> [MouseGestureRecognition] {
        switch event.phase {
        case .down:
            presses[event.button] = PressState(
                location: event.location,
                timestamp: event.timestamp,
                screenSize: Self.validScreenSize(screenSize),
                dragDirection: nil
            )
            return []

        case .dragged:
            guard var press = presses[event.button] else { return [] }
            guard let direction = Self.dragDirection(
                from: press.location,
                to: event.location,
                screenSize: press.screenSize,
                thresholdRatio: dragThresholdRatio
            ) else {
                return []
            }
            press.dragDirection = direction
            presses[event.button] = press
            return [
                .dragPreview(event.button, direction, press.location, event.location)
            ]

        case .up:
            guard let press = presses.removeValue(forKey: event.button) else { return [] }
            if let direction = press.dragDirection {
                return [
                    .dismissDragPreview(event.button),
                    .gesture(event.button, direction.gesture)
                ]
            }

            guard event.timestamp - press.timestamp <= Self.maximumClickDuration else {
                return [.dismissDragPreview(event.button)]
            }

            guard supportsDoubleClick else {
                return [.gesture(event.button, .singleClick)]
            }

            if let pending = pendingClicks[event.button],
               event.timestamp - pending.timestamp <= doubleClickInterval {
                pendingClicks.removeValue(forKey: event.button)
                return [
                    .cancelSingleClick(event.button, pending.token),
                    .gesture(event.button, .doubleClick)
                ]
            }

            let token = UUID()
            pendingClicks[event.button] = PendingClick(
                token: token,
                timestamp: event.timestamp
            )
            return [
                .scheduleSingleClick(
                    event.button,
                    token,
                    event.timestamp + doubleClickInterval
                )
            ]
        }
    }

    mutating func completePendingSingleClick(
        for button: MouseSideButton,
        token: UUID
    ) -> MouseGestureRecognition? {
        guard pendingClicks[button]?.token == token else { return nil }
        pendingClicks.removeValue(forKey: button)
        return .gesture(button, .singleClick)
    }

    mutating func reset() -> [MouseGestureRecognition] {
        let previews = presses.compactMap { button, state in
            state.dragDirection == nil ? nil : MouseGestureRecognition.dismissDragPreview(button)
        }
        presses.removeAll()
        pendingClicks.removeAll()
        return previews
    }

    static func dragDirection(
        from origin: CGPoint,
        to location: CGPoint,
        screenSize: CGSize = referenceScreenSize,
        thresholdRatio: Double = MouseGestureConfiguration.defaultDragThresholdRatio
    ) -> MouseDragDirection? {
        let deltaX = location.x - origin.x
        let deltaY = location.y - origin.y
        let validSize = validScreenSize(screenSize)
        let ratio = CGFloat(
            MouseGestureConfiguration.normalizedDragThresholdRatio(thresholdRatio)
        )

        if abs(deltaX) >= abs(deltaY) {
            guard abs(deltaX) >= validSize.width * ratio else { return nil }
            return deltaX < 0 ? .left : .right
        }
        // Core Graphics uses a top-left global origin for event locations.
        guard abs(deltaY) >= validSize.height * ratio else { return nil }
        return deltaY < 0 ? .up : .down
    }

    private static func validScreenSize(_ screenSize: CGSize) -> CGSize {
        guard screenSize.width > 0, screenSize.height > 0 else {
            return referenceScreenSize
        }
        return screenSize
    }
}
