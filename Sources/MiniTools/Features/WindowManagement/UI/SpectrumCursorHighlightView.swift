import AppKit
import QuartzCore

@MainActor
final class SpectrumCursorHighlightView: CursorHighlightEffectView {
    private var spectrumColors: [CGColor] {
        [
            NSColor(calibratedRed: 0.15, green: 0.82, blue: 1.00, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.20, green: 0.42, blue: 1.00, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.62, green: 0.28, blue: 1.00, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.00, green: 0.22, blue: 0.68, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.42, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.15, green: 0.82, blue: 1.00, alpha: 1).cgColor
        ]
    }

    override func startAnimation() {
        let startTime = CACurrentMediaTime()
        addAmbientGlow(startTime: startTime)
        addGradientWave(
            startTime: startTime,
            delay: 0,
            lineWidth: CursorHighlightPresentationMetrics.size(7),
            inset: CursorHighlightPresentationMetrics.size(27)
        )
        addGradientWave(
            startTime: startTime,
            delay: CursorHighlightPresentationMetrics.duration(0.2),
            lineWidth: CursorHighlightPresentationMetrics.size(3.5),
            inset: CursorHighlightPresentationMetrics.size(20)
        )
        addOrbitingLights(
            startTime: startTime + CursorHighlightPresentationMetrics.duration(0.04)
        )
        addCenterSpark(startTime: startTime)
    }

    private func addAmbientGlow(startTime: CFTimeInterval) {
        guard let rootLayer = layer else { return }
        let glow = CAGradientLayer()
        let inset = CursorHighlightPresentationMetrics.size(22)
        glow.frame = bounds.insetBy(dx: inset, dy: inset)
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.colors = [
            NSColor.white.withAlphaComponent(0.35).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.28).cgColor,
            NSColor.systemPurple.withAlphaComponent(0.18).cgColor,
            NSColor.clear.cgColor
        ]
        glow.locations = [0, 0.22, 0.58, 1]
        glow.cornerRadius = glow.bounds.width / 2
        rootLayer.addSublayer(glow)

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.32, 0.72, 1.08, 1.2]
        scale.keyTimes = [0, 0.22, 0.72, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.72, 0.38, 0]
        opacity.keyTimes = [0, 0.18, 0.68, 1]
        glow.add(
            animationGroup(
                animations: [scale, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.3)
            ),
            forKey: "ambientGlow"
        )
    }

    private func addGradientWave(
        startTime: CFTimeInterval,
        delay: CFTimeInterval,
        lineWidth: CGFloat,
        inset: CGFloat
    ) {
        guard let rootLayer = layer else { return }
        let wave = CALayer()
        wave.frame = bounds
        rootLayer.addSublayer(wave)

        let gradient = CAGradientLayer()
        gradient.frame = wave.bounds
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.colors = spectrumColors
        gradient.locations = [0, 0.18, 0.38, 0.6, 0.82, 1]
        gradient.shadowColor = NSColor.systemPurple.cgColor
        gradient.shadowOpacity = 0.85
        gradient.shadowRadius = lineWidth * 2.1
        gradient.shadowOffset = .zero

        let mask = CAShapeLayer()
        mask.frame = gradient.bounds
        mask.path = CGPath(
            ellipseIn: gradient.bounds.insetBy(dx: inset, dy: inset),
            transform: nil
        )
        mask.fillColor = NSColor.clear.cgColor
        mask.strokeColor = NSColor.white.cgColor
        mask.lineWidth = lineWidth
        gradient.mask = mask
        wave.addSublayer(gradient)

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2.15
        rotation.beginTime = startTime + delay
        rotation.duration = CursorHighlightPresentationMetrics.duration(1.12)
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rotation.fillMode = .both
        rotation.isRemovedOnCompletion = false
        gradient.add(rotation, forKey: "spectrumRotation")

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.38, 0.68, 1, 1.1]
        scale.keyTimes = [0, 0.2, 0.72, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.82, 0]
        opacity.keyTimes = [0, 0.16, 0.7, 1]
        wave.add(
            animationGroup(
                animations: [scale, opacity],
                startTime: startTime + delay,
                duration: CursorHighlightPresentationMetrics.duration(1.14)
            ),
            forKey: "spectrumWave"
        )
    }

    private func addOrbitingLights(startTime: CFTimeInterval) {
        guard let rootLayer = layer else { return }
        let orbit = CALayer()
        orbit.frame = bounds
        rootLayer.addSublayer(orbit)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = CursorHighlightPresentationMetrics.size(41)
        let colors = spectrumColors.dropLast(2)
        for (index, color) in colors.enumerated() {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(colors.count)
            let dotSize = CursorHighlightPresentationMetrics.size(
                index.isMultiple(of: 2) ? 8 : 6
            )
            let dot = CAShapeLayer()
            dot.frame = CGRect(
                x: center.x + cos(angle) * radius - dotSize / 2,
                y: center.y + sin(angle) * radius - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            dot.path = CGPath(ellipseIn: dot.bounds, transform: nil)
            dot.fillColor = color
            dot.shadowColor = color
            dot.shadowOpacity = 1
            dot.shadowRadius = CursorHighlightPresentationMetrics.size(7)
            dot.shadowOffset = .zero
            orbit.addSublayer(dot)
        }

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [0, Double.pi * 0.8, Double.pi * 2.45]
        rotation.keyTimes = [0, 0.34, 1]
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.42, 0.78, 1.02, 1.12]
        scale.keyTimes = [0, 0.22, 0.7, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.9, 0]
        opacity.keyTimes = [0, 0.14, 0.72, 1]
        orbit.add(
            animationGroup(
                animations: [rotation, scale, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.18)
            ),
            forKey: "orbitingLights"
        )
    }

    private func addCenterSpark(startTime: CFTimeInterval) {
        guard let rootLayer = layer else { return }
        let size = CursorHighlightPresentationMetrics.size(11)
        let spark = CAShapeLayer()
        spark.frame = CGRect(
            x: bounds.midX - size / 2,
            y: bounds.midY - size / 2,
            width: size,
            height: size
        )
        spark.path = CGPath(ellipseIn: spark.bounds, transform: nil)
        spark.fillColor = NSColor.white.cgColor
        spark.shadowColor = NSColor.systemCyan.cgColor
        spark.shadowOpacity = 1
        spark.shadowRadius = CursorHighlightPresentationMetrics.size(12)
        spark.shadowOffset = .zero
        rootLayer.addSublayer(spark)

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.2, 1.35, 0.9, 0.35]
        scale.keyTimes = [0, 0.2, 0.62, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.9, 0]
        opacity.keyTimes = [0, 0.12, 0.62, 1]
        spark.add(
            animationGroup(
                animations: [scale, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.24)
            ),
            forKey: "centerSpark"
        )
    }
}
