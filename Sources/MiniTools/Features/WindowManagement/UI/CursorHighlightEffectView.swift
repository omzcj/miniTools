import AppKit
import QuartzCore

enum CursorHighlightPresentationMetrics {
    static let sizeScale: CGFloat = 1.25
    static let durationScale: CFTimeInterval = 1.4

    static func size(_ value: CGFloat) -> CGFloat {
        value * sizeScale
    }

    static func duration(_ value: CFTimeInterval) -> CFTimeInterval {
        value * durationScale
    }
}

@MainActor
class CursorHighlightEffectView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    func startAnimation() {}

    func animationGroup(
        animations: [CAAnimation],
        startTime: CFTimeInterval,
        duration: CFTimeInterval,
        timingFunction: CAMediaTimingFunctionName = .easeOut
    ) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.animations = animations
        group.beginTime = startTime
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: timingFunction)
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        return group
    }
}
