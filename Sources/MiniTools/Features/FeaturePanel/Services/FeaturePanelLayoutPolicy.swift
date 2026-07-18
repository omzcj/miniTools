import CoreGraphics

enum FeaturePanelLayoutPolicy {
    static let fallbackVisibleFrame = CGRect(
        origin: .zero,
        size: CGSize(width: 1440, height: 900)
    )

    static func availableSize(in visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: max(
                FeaturePanelMetrics.minimumWidth,
                visibleFrame.width - FeaturePanelMetrics.screenHorizontalInset
            ),
            height: max(
                FeaturePanelMetrics.safariFixedHeight
                    + FeaturePanelMetrics.safariMinimumBodyHeight,
                visibleFrame.height - FeaturePanelMetrics.screenVerticalInset
            )
        )
    }

    static func encodingPanelSize(in visibleFrame: CGRect) -> CGSize {
        let availableSize = availableSize(in: visibleFrame)
        return CGSize(
            width: FeaturePanelMetrics.panelWidth(availableWidth: availableSize.width),
            height: min(FeaturePanelMetrics.encodingPanelHeight, availableSize.height)
        )
    }

    static func safariLayout(windowCount: Int, in visibleFrame: CGRect) -> SafariPanelLayout {
        SafariPanelLayout.calculate(
            windowCount: windowCount,
            availableSize: availableSize(in: visibleFrame)
        )
    }

    static func targetFrame(
        contentSize: CGSize,
        visibleFrame: CGRect,
        currentFrame: CGRect?
    ) -> CGRect {
        if let currentFrame {
            return CGRect(
                x: currentFrame.midX - contentSize.width / 2,
                y: currentFrame.maxY - contentSize.height,
                width: contentSize.width,
                height: contentSize.height
            )
        }

        return CGRect(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.maxY - contentSize.height - FeaturePanelMetrics.panelTopInset,
            width: contentSize.width,
            height: contentSize.height
        )
    }
}
