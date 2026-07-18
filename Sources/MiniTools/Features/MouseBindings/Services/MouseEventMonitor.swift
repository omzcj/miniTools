@preconcurrency import CoreGraphics
import Foundation

private let miniToolsMouseEventTapCallback: CGEventTapCallBack = {
    _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitorAddress = Int(bitPattern: userInfo)
    return MainActor.assumeIsolated {
        guard let monitorPointer = UnsafeMutableRawPointer(bitPattern: monitorAddress) else {
            return Unmanaged.passUnretained(event)
        }
        let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(monitorPointer).takeUnretainedValue()
        return monitor.handle(type: type, event: event)
    }
}

@MainActor
final class MouseEventMonitor {
    typealias EventHandler = (MouseButtonEvent) -> Bool

    private let eventHandler: EventHandler
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(eventHandler: @escaping EventHandler) {
        self.eventHandler = eventHandler
    }

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        stop()

        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: miniToolsMouseEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard
            let phase = Self.phase(for: type),
            let button = MouseSideButton(
                eventButtonNumber: event.getIntegerValueField(.mouseEventButtonNumber)
            )
        else {
            return Unmanaged.passUnretained(event)
        }

        let handled = eventHandler(
            MouseButtonEvent(
                button: button,
                phase: phase,
                location: event.location,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
        )
        return handled ? nil : Unmanaged.passUnretained(event)
    }

    private static func phase(for type: CGEventType) -> MouseButtonEventPhase? {
        switch type {
        case .otherMouseDown: .down
        case .otherMouseDragged: .dragged
        case .otherMouseUp: .up
        default: nil
        }
    }
}
