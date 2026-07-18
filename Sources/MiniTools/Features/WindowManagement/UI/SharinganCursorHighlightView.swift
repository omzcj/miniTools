import AppKit
import QuartzCore

@MainActor
final class SharinganCursorHighlightView: CursorHighlightEffectView {
    nonisolated static let canvasSize = CGSize(
        width: CursorHighlightPresentationMetrics.size(220),
        height: CursorHighlightPresentationMetrics.size(220)
    )
    nonisolated static let eyeDiameter = CursorHighlightPresentationMetrics.size(104)

    private let style: CursorHighlightStyle

    init(style: CursorHighlightStyle, frame: CGRect) {
        self.style = style
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func startAnimation() {
        guard
            let rootLayer = layer,
            let artwork = SharinganArtwork.renderedArtwork(for: style)
        else {
            return
        }

        let startTime = CACurrentMediaTime()
        let eyeSize = min(Self.eyeDiameter, min(bounds.width, bounds.height))
        let eyeFrame = CGRect(
            x: bounds.midX - eyeSize / 2,
            y: bounds.midY - eyeSize / 2,
            width: eyeSize,
            height: eyeSize
        )

        addExpandingAura(
            to: rootLayer,
            eyeFrame: eyeFrame,
            color: artwork.glowColor,
            startTime: startTime
        )

        let eye = CALayer()
        eye.frame = eyeFrame
        eye.cornerRadius = eyeSize / 2
        eye.masksToBounds = false
        eye.shadowPath = CGPath(ellipseIn: eye.bounds, transform: nil)
        eye.shadowColor = artwork.glowColor.cgColor
        eye.shadowOpacity = 0.95
        eye.shadowRadius = CursorHighlightPresentationMetrics.size(17)
        eye.shadowOffset = .zero
        rootLayer.addSublayer(eye)

        let clip = CALayer()
        clip.frame = eye.bounds
        clip.cornerRadius = eyeSize / 2
        clip.masksToBounds = true
        eye.addSublayer(clip)

        let image = CALayer()
        image.frame = clip.bounds
        image.contents = artwork.image
        image.contentsGravity = .resizeAspectFill
        image.contentsScale = layer?.contentsScale ?? 2
        image.minificationFilter = .trilinear
        image.magnificationFilter = .linear
        clip.addSublayer(image)

        animateEye(
            eye,
            artworkLayer: image,
            rotationDirection: artwork.rotationDirection,
            startTime: startTime
        )
    }

    private func addExpandingAura(
        to parent: CALayer,
        eyeFrame: CGRect,
        color: NSColor,
        startTime: CFTimeInterval
    ) {
        for index in 0..<2 {
            let aura = CAShapeLayer()
            aura.frame = eyeFrame
            let inset = CursorHighlightPresentationMetrics.size(3)
            aura.path = CGPath(
                ellipseIn: aura.bounds.insetBy(dx: inset, dy: inset),
                transform: nil
            )
            aura.fillColor = NSColor.clear.cgColor
            aura.strokeColor = color.withAlphaComponent(index == 0 ? 0.7 : 0.38).cgColor
            aura.lineWidth = CursorHighlightPresentationMetrics.size(
                index == 0 ? 3 : 1.5
            )
            aura.shadowPath = aura.path
            aura.shadowColor = color.cgColor
            aura.shadowOpacity = 0.95
            aura.shadowRadius = CursorHighlightPresentationMetrics.size(9)
            aura.shadowOffset = .zero
            parent.addSublayer(aura)

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.45, 0.96, 1.38 + CGFloat(index) * 0.22]
            scale.keyTimes = [0, 0.32, 1]
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 0.85, 0]
            opacity.keyTimes = [0, 0.28, 1]
            aura.add(
                animationGroup(
                    animations: [scale, opacity],
                    startTime: startTime
                        + Double(index) * CursorHighlightPresentationMetrics.duration(0.12),
                    duration: CursorHighlightPresentationMetrics.duration(1.28)
                ),
                forKey: "eyeAura"
            )
        }
    }

    private func animateEye(
        _ eye: CALayer,
        artworkLayer: CALayer,
        rotationDirection: CGFloat,
        startTime: CFTimeInterval
    ) {
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.12, 1.12, 0.92, 1.02, 1.12]
        scale.keyTimes = [0, 0.22, 0.48, 0.72, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0.88, 0]
        opacity.keyTimes = [0, 0.13, 0.7, 0.86, 1]
        eye.add(
            animationGroup(
                animations: [scale, opacity],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.48),
                timingFunction: .easeInEaseOut
            ),
            forKey: "eyeEntrance"
        )

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let direction = Double(rotationDirection)
        rotation.values = [0, direction * .pi * 0.5, direction * .pi * 2.15]
        rotation.keyTimes = [0, 0.35, 1]
        artworkLayer.add(
            animationGroup(
                animations: [rotation],
                startTime: startTime,
                duration: CursorHighlightPresentationMetrics.duration(1.3),
                timingFunction: .easeInEaseOut
            ),
            forKey: "artworkRotation"
        )
    }
}
