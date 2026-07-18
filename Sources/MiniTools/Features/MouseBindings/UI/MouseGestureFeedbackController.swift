import AppKit
import QuartzCore

@MainActor
final class MouseGestureFeedbackController {
    private var panel: NSPanel?
    private weak var pathView: MouseGesturePathView?
    private var dismissWorkItem: DispatchWorkItem?

    func updatePath(
        fromAccessibilityPoint origin: CGPoint,
        toAccessibilityPoint current: CGPoint,
        direction: MouseDragDirection,
        hasAssignedAction: Bool
    ) {
        dismissWorkItem?.cancel()
        let panel = panel ?? makePanel()
        guard let pathView else { return }

        let originPoint = localAppKitPoint(fromAccessibilityPoint: origin, in: panel.frame)
        let currentPoint = localAppKitPoint(fromAccessibilityPoint: current, in: panel.frame)
        pathView.update(
            origin: originPoint,
            current: currentPoint,
            direction: direction,
            isActive: hasAssignedAction
        )

        if !panel.isVisible {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        guard let panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.pathView?.reset()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13, execute: workItem)
    }

    private func makePanel() -> NSPanel {
        let frame = NSScreen.screens.map(\.frame).reduce(CGRect.null) { partial, frame in
            partial.union(frame)
        }
        let resolvedFrame = frame.isNull
            ? CGRect(x: 0, y: 0, width: 1, height: 1)
            : frame
        let pathView = MouseGesturePathView(
            frame: CGRect(origin: .zero, size: resolvedFrame.size)
        )
        let panel = NSPanel(
            contentRect: resolvedFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = pathView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle
        ]

        self.panel = panel
        self.pathView = pathView
        return panel
    }

    private func localAppKitPoint(
        fromAccessibilityPoint point: CGPoint,
        in windowFrame: CGRect
    ) -> CGPoint {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let appKitPoint = CGPoint(x: point.x, y: primaryMaxY - point.y)
        return CGPoint(
            x: appKitPoint.x - windowFrame.minX,
            y: appKitPoint.y - windowFrame.minY
        )
    }
}

private final class MouseGesturePathView: NSView {
    private let glowLayer = CAShapeLayer()
    private let pathLayer = CAShapeLayer()
    private let originLayer = CAShapeLayer()
    private let arrowLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let layer else { return }

        [glowLayer, pathLayer, originLayer, arrowLayer, pulseLayer].forEach {
            $0.fillColor = NSColor.clear.cgColor
            layer.addSublayer($0)
        }

        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round
        glowLayer.lineWidth = 11
        glowLayer.opacity = 0.26

        pathLayer.lineCap = .round
        pathLayer.lineJoin = .round
        pathLayer.lineWidth = 3.5
        pathLayer.lineDashPattern = [12, 9]

        originLayer.lineWidth = 2
        originLayer.fillColor = NSColor.clear.cgColor

        arrowLayer.lineJoin = .round
        arrowLayer.lineCap = .round
        arrowLayer.lineWidth = 3

        pulseLayer.lineWidth = 2.5
        pulseLayer.fillColor = NSColor.clear.cgColor

        let dashAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        dashAnimation.fromValue = 0
        dashAnimation.toValue = -21
        dashAnimation.duration = 0.48
        dashAnimation.repeatCount = .infinity
        pathLayer.add(dashAnimation, forKey: "flow")

        let pulseScale = CABasicAnimation(keyPath: "transform.scale")
        pulseScale.fromValue = 0.72
        pulseScale.toValue = 1.5
        let pulseOpacity = CABasicAnimation(keyPath: "opacity")
        pulseOpacity.fromValue = 0.9
        pulseOpacity.toValue = 0
        let pulseGroup = CAAnimationGroup()
        pulseGroup.animations = [pulseScale, pulseOpacity]
        pulseGroup.duration = 0.72
        pulseGroup.repeatCount = .infinity
        pulseLayer.add(pulseGroup, forKey: "pulse")
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(
        origin: CGPoint,
        current: CGPoint,
        direction: MouseDragDirection,
        isActive: Bool
    ) {
        let path = curvedPath(from: origin, to: current)
        let color = isActive
            ? NSColor.controlAccentColor
            : NSColor.tertiaryLabelColor
        let arrowPath = arrowHead(at: current, direction: direction)
        let originPath = CGPath(
            ellipseIn: CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10),
            transform: nil
        )
        let pulseBounds = CGRect(x: 0, y: 0, width: 22, height: 22)
        let pulsePath = CGPath(
            ellipseIn: pulseBounds.insetBy(dx: 2, dy: 2),
            transform: nil
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.path = path
        glowLayer.strokeColor = color.cgColor
        pathLayer.path = path
        pathLayer.strokeColor = color.cgColor
        originLayer.path = originPath
        originLayer.strokeColor = color.cgColor
        arrowLayer.path = arrowPath
        arrowLayer.strokeColor = color.cgColor
        arrowLayer.fillColor = color.cgColor
        pulseLayer.bounds = pulseBounds
        pulseLayer.position = current
        pulseLayer.path = pulsePath
        pulseLayer.strokeColor = color.cgColor
        CATransaction.commit()
    }

    func reset() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.path = nil
        pathLayer.path = nil
        originLayer.path = nil
        arrowLayer.path = nil
        pulseLayer.path = nil
        CATransaction.commit()
    }

    private func curvedPath(from origin: CGPoint, to current: CGPoint) -> CGPath {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y
        let distance = max(hypot(deltaX, deltaY), 1)
        let bend = min(20, distance * 0.07)
        let control = CGPoint(
            x: (origin.x + current.x) / 2 - deltaY / distance * bend,
            y: (origin.y + current.y) / 2 + deltaX / distance * bend
        )
        let path = CGMutablePath()
        path.move(to: origin)
        path.addQuadCurve(to: current, control: control)
        return path
    }

    private func arrowHead(
        at point: CGPoint,
        direction: MouseDragDirection
    ) -> CGPath {
        let vector: CGPoint
        switch direction {
        case .up: vector = CGPoint(x: 0, y: 1)
        case .down: vector = CGPoint(x: 0, y: -1)
        case .left: vector = CGPoint(x: -1, y: 0)
        case .right: vector = CGPoint(x: 1, y: 0)
        }
        let perpendicular = CGPoint(x: -vector.y, y: vector.x)
        let tip = CGPoint(x: point.x + vector.x * 11, y: point.y + vector.y * 11)
        let base = CGPoint(x: point.x - vector.x * 7, y: point.y - vector.y * 7)
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: CGPoint(
            x: base.x + perpendicular.x * 8,
            y: base.y + perpendicular.y * 8
        ))
        path.addLine(to: CGPoint(
            x: base.x - perpendicular.x * 8,
            y: base.y - perpendicular.y * 8
        ))
        path.closeSubpath()
        return path
    }
}
