import CoreGraphics

struct SafariPanelLayout: Equatable {
    let rowHeight: CGFloat
    let rowSpacing: CGFloat
    let contentSize: CGSize

    static let empty = empty(availableSize: CGSize(
        width: FeaturePanelMetrics.preferredWidth,
        height: FeaturePanelMetrics.safariFixedHeight
            + FeaturePanelMetrics.safariMinimumBodyHeight
    ))

    private static func empty(availableSize: CGSize) -> SafariPanelLayout {
        SafariPanelLayout(
            rowHeight: FeaturePanelMetrics.safariPreferredRowHeight,
            rowSpacing: FeaturePanelMetrics.safariPreferredRowSpacing,
            contentSize: CGSize(
                width: FeaturePanelMetrics.panelWidth(availableWidth: availableSize.width),
                height: FeaturePanelMetrics.safariFixedHeight
                    + FeaturePanelMetrics.safariMinimumBodyHeight
            )
        )
    }

    static func calculate(windowCount: Int, availableSize: CGSize) -> SafariPanelLayout {
        guard windowCount > 0 else { return empty(availableSize: availableSize) }

        let fixedHeight = FeaturePanelMetrics.safariFixedHeight
        let preferredRowHeight = FeaturePanelMetrics.safariPreferredRowHeight
        let preferredRowSpacing = FeaturePanelMetrics.safariPreferredRowSpacing
        let minimumHeight = fixedHeight + FeaturePanelMetrics.safariMinimumBodyHeight
        let usableWidth = max(FeaturePanelMetrics.minimumWidth, availableSize.width)
        let usableHeight = max(minimumHeight, availableSize.height)
        let rowCount = CGFloat(windowCount)
        let availableListHeight = max(1, usableHeight - fixedHeight)
        let rowSpacing = windowCount > 1
            ? min(
                preferredRowSpacing,
                max(0, (availableListHeight - rowCount) / CGFloat(windowCount - 1))
            )
            : 0
        let spacingHeight = CGFloat(max(0, windowCount - 1)) * rowSpacing
        let fittedRowHeight = floor(
            max(1, (availableListHeight - spacingHeight) / rowCount)
        )
        let rowHeight = min(preferredRowHeight, fittedRowHeight)
        let contentHeight = fixedHeight + spacingHeight + rowHeight * rowCount

        return SafariPanelLayout(
            rowHeight: rowHeight,
            rowSpacing: rowSpacing,
            contentSize: CGSize(
                width: FeaturePanelMetrics.panelWidth(availableWidth: usableWidth),
                height: min(usableHeight, contentHeight)
            )
        )
    }
}
