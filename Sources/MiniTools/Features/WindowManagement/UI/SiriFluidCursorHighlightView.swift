import AppKit
import QuartzCore

@MainActor
final class SiriFluidCursorHighlightView: CursorHighlightEffectView {
    private let fluidColors: [[CGColor]] = [
        [
            NSColor(calibratedRed: 0.05, green: 0.88, blue: 1.00, alpha: 0.96).cgColor,
            NSColor(calibratedRed: 0.12, green: 0.55, blue: 1.00, alpha: 0.72).cgColor,
            NSColor.clear.cgColor
        ],
        [
            NSColor(calibratedRed: 0.36, green: 0.30, blue: 1.00, alpha: 0.96).cgColor,
            NSColor(calibratedRed: 0.65, green: 0.22, blue: 1.00, alpha: 0.72).cgColor,
            NSColor.clear.cgColor
        ],
        [
            NSColor(calibratedRed: 1.00, green: 0.17, blue: 0.66, alpha: 0.96).cgColor,
            NSColor(calibratedRed: 1.00, green: 0.35, blue: 0.38, alpha: 0.68).cgColor,
            NSColor.clear.cgColor
        ],
        [
            NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.12, alpha: 0.92).cgColor,
            NSColor(calibratedRed: 1.00, green: 0.20, blue: 0.50, alpha: 0.62).cgColor,
            NSColor.clear.cgColor
        ]
    ]

    override func startAnimation() {
        guard let rootLayer = layer else { return }
        let startTime = CACurrentMediaTime()
        let fluidInset = CursorHighlightPresentationMetrics.size(24)
        let fluidFrame = bounds.insetBy(dx: fluidInset, dy: fluidInset)
        let fluid = CALayer()
        fluid.frame = fluidFrame
        fluid.shadowColor = NSColor.systemPurple.cgColor
        fluid.shadowOpacity = 0.78
        fluid.shadowRadius = CursorHighlightPresentationMetrics.size(19)
        fluid.shadowOffset = .zero
        rootLayer.addSublayer(fluid)

        let phases: [CGFloat] = [0, 0.8, 1.6, 2.5, 3.4]
        let paths = phases.map { organicPath(in: fluid.bounds, phase: $0) }
        let fluidMask = CAShapeLayer()
        fluidMask.frame = fluid.bounds
        fluidMask.path = paths[0]
        fluid.mask = fluidMask

        addDarkCore(to: fluid)
        addFluidBlobs(to: fluid, startTime: startTime)
        addLuminousRim(to: rootLayer, frame: fluidFrame, paths: paths, startTime: startTime)
        addCenterPulse(to: rootLayer, startTime: startTime)

        let morph = CAKeyframeAnimation(keyPath: "path")
        morph.values = paths
        morph.keyTimes = [0, 0.24, 0.49, 0.75, 1]
        morph.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: phases.count - 1
        )
        morph.beginTime = startTime
        morph.duration = CursorHighlightPresentationMetrics.duration(1.38)
        morph.fillMode = .both
        morph.isRemovedOnCompletion = false
        fluidMask.add(morph, forKey: "organicMorph")

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.12, 0.74, 1.04, 0.92, 1.13]
        scale.keyTimes = [0, 0.2, 0.46, 0.76, 1]
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [-0.22, 0.12, -0.08, 0.16]
        rotation.keyTimes = [0, 0.36, 0.7, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.96, 0.68, 0]
        opacity.keyTimes = [0, 0.14, 0.64, 0.84, 1]
        fluid.add(
            animationGroup(
                animations: [scale, rotation, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.52),
                timingFunction: .easeInEaseOut
            ),
            forKey: "fluidEntrance"
        )
    }

    private func addDarkCore(to parent: CALayer) {
        let core = CAGradientLayer()
        core.frame = parent.bounds
        core.type = .radial
        core.startPoint = CGPoint(x: 0.48, y: 0.52)
        core.endPoint = CGPoint(x: 1, y: 1)
        core.colors = [
            NSColor(calibratedWhite: 0.03, alpha: 0.86).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.03, blue: 0.18, alpha: 0.7).cgColor,
            NSColor(calibratedWhite: 0.02, alpha: 0.28).cgColor
        ]
        core.locations = [0, 0.5, 1]
        parent.addSublayer(core)
    }

    private func addFluidBlobs(to parent: CALayer, startTime: CFTimeInterval) {
        let width = parent.bounds.width
        let centers: [[CGPoint]] = [
            [CGPoint(x: 0.18, y: 0.70), CGPoint(x: 0.54, y: 0.76), CGPoint(x: 0.73, y: 0.46)],
            [CGPoint(x: 0.70, y: 0.72), CGPoint(x: 0.40, y: 0.54), CGPoint(x: 0.22, y: 0.30)],
            [CGPoint(x: 0.72, y: 0.22), CGPoint(x: 0.46, y: 0.28), CGPoint(x: 0.58, y: 0.66)],
            [CGPoint(x: 0.26, y: 0.20), CGPoint(x: 0.68, y: 0.40), CGPoint(x: 0.38, y: 0.74)]
        ]

        for (index, colors) in fluidColors.enumerated() {
            let blobSize = width * (index.isMultiple(of: 2) ? 0.88 : 0.78)
            let blob = CAGradientLayer()
            blob.bounds = CGRect(x: 0, y: 0, width: blobSize, height: blobSize)
            blob.position = CGPoint(
                x: centers[index][0].x * width,
                y: centers[index][0].y * width
            )
            blob.type = .radial
            blob.startPoint = CGPoint(x: 0.5, y: 0.5)
            blob.endPoint = CGPoint(x: 1, y: 1)
            blob.colors = colors
            blob.locations = [0, 0.44, 1]
            blob.compositingFilter = "screenBlendMode"
            parent.addSublayer(blob)

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = centers[index].map {
                NSValue(point: NSPoint(x: $0.x * width, y: $0.y * width))
            }
            position.keyTimes = [0, 0.52, 1]
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = index.isMultiple(of: 2)
                ? [0.68, 1.16, 0.82]
                : [1.02, 0.72, 1.18]
            scale.keyTimes = [0, 0.48, 1]
            blob.add(
                animationGroup(
                    animations: [position, scale],
                    startTime: startTime
                        + Double(index) * CursorHighlightPresentationMetrics.duration(0.035),
                    duration: CursorHighlightPresentationMetrics.duration(1.28),
                    timingFunction: .easeInEaseOut
                ),
                forKey: "fluidBlob"
            )
        }
    }

    private func addLuminousRim(
        to parent: CALayer,
        frame: CGRect,
        paths: [CGPath],
        startTime: CFTimeInterval
    ) {
        let rim = CAGradientLayer()
        rim.frame = frame
        rim.type = .conic
        rim.startPoint = CGPoint(x: 0.5, y: 0.5)
        rim.endPoint = CGPoint(x: 0.5, y: 0)
        rim.colors = fluidColors.flatMap { [$0[0]] }
            + [fluidColors[0][0]]
        rim.shadowColor = NSColor.white.cgColor
        rim.shadowOpacity = 0.7
        rim.shadowRadius = CursorHighlightPresentationMetrics.size(7)
        rim.shadowOffset = .zero

        let rimMask = CAShapeLayer()
        rimMask.frame = rim.bounds
        rimMask.path = paths[0]
        rimMask.fillColor = NSColor.clear.cgColor
        rimMask.strokeColor = NSColor.white.cgColor
        rimMask.lineWidth = CursorHighlightPresentationMetrics.size(4.5)
        rim.mask = rimMask
        parent.addSublayer(rim)

        let morph = CAKeyframeAnimation(keyPath: "path")
        morph.values = paths
        morph.keyTimes = [0, 0.24, 0.49, 0.75, 1]
        let stroke = CAKeyframeAnimation(keyPath: "strokeEnd")
        stroke.values = [0, 0.56, 1, 1]
        stroke.keyTimes = [0, 0.22, 0.54, 1]
        rimMask.add(
            animationGroup(
                animations: [morph, stroke],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.4),
                timingFunction: .easeInEaseOut
            ),
            forKey: "rimMorph"
        )

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = -0.35
        rotation.toValue = Double.pi * 1.75
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.92, 0]
        opacity.keyTimes = [0, 0.12, 0.76, 1]
        rim.add(
            animationGroup(
                animations: [rotation, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.52),
                timingFunction: .easeInEaseOut
            ),
            forKey: "rimFlow"
        )
    }

    private func addCenterPulse(to parent: CALayer, startTime: CFTimeInterval) {
        let pulse = CAShapeLayer()
        let pulseSize = CursorHighlightPresentationMetrics.size(18)
        pulse.frame = CGRect(
            x: bounds.midX - pulseSize / 2,
            y: bounds.midY - pulseSize / 2,
            width: pulseSize,
            height: pulseSize
        )
        pulse.path = CGPath(ellipseIn: pulse.bounds, transform: nil)
        pulse.fillColor = NSColor.white.withAlphaComponent(0.92).cgColor
        pulse.shadowColor = NSColor.systemCyan.cgColor
        pulse.shadowOpacity = 1
        pulse.shadowRadius = CursorHighlightPresentationMetrics.size(16)
        pulse.shadowOffset = .zero
        parent.addSublayer(pulse)

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.08, 0.4, 1.1, 0.28, 0.06]
        scale.keyTimes = [0, 0.16, 0.38, 0.74, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.84, 0.42, 0]
        opacity.keyTimes = [0, 0.12, 0.48, 0.78, 1]
        pulse.add(
            animationGroup(
                animations: [scale, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.46)
            ),
            forKey: "centerPulse"
        )
    }

    private func organicPath(in rect: CGRect, phase: CGFloat) -> CGPath {
        let pointCount = 12
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.455
        let points = (0..<pointCount).map { index -> CGPoint in
            let angle = CGFloat(index) * 2 * .pi / CGFloat(pointCount)
            let wave = sin(angle * 3 + phase) * 0.075
                + cos(angle * 2 - phase * 1.35) * 0.055
            let radius = baseRadius * (1 + wave)
            return CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }

        let path = CGMutablePath()
        let firstMidpoint = midpoint(points[pointCount - 1], points[0])
        path.move(to: firstMidpoint)
        for index in points.indices {
            let next = points[(index + 1) % pointCount]
            path.addQuadCurve(to: midpoint(points[index], next), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }
}
