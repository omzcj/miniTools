import CoreGraphics
import XCTest
@testable import MiniTools

final class FeaturePanelTests: XCTestCase {
    func testEncodingAndSafariPanelsUseTheSameWidth() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let encodingSize = FeaturePanelLayoutPolicy.encodingPanelSize(in: visibleFrame)
        let safariLayout = FeaturePanelLayoutPolicy.safariLayout(
            windowCount: 8,
            in: visibleFrame
        )

        XCTAssertEqual(encodingSize.width, FeaturePanelMetrics.preferredWidth)
        XCTAssertEqual(safariLayout.contentSize.width, encodingSize.width)
    }

    func testEmptySafariPanelStillFitsACompactScreen() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 350, height: 600)
        let encodingSize = FeaturePanelLayoutPolicy.encodingPanelSize(in: visibleFrame)
        let safariLayout = FeaturePanelLayoutPolicy.safariLayout(
            windowCount: 0,
            in: visibleFrame
        )

        XCTAssertEqual(safariLayout.contentSize.width, encodingSize.width)
        XCTAssertLessThanOrEqual(safariLayout.contentSize.width, visibleFrame.width)
    }

    func testVisiblePanelResizeKeepsItsTopEdgeAndHorizontalCenter() {
        let currentFrame = CGRect(x: 300, y: 200, width: 560, height: 568)
        let targetFrame = FeaturePanelLayoutPolicy.targetFrame(
            contentSize: CGSize(width: 560, height: 300),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            currentFrame: currentFrame
        )

        XCTAssertEqual(targetFrame.midX, currentFrame.midX)
        XCTAssertEqual(targetFrame.maxY, currentFrame.maxY)
    }

    func testHiddenPanelUsesConfiguredTopInset() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1440, height: 876)
        let targetFrame = FeaturePanelLayoutPolicy.targetFrame(
            contentSize: CGSize(width: 560, height: 568),
            visibleFrame: visibleFrame,
            currentFrame: nil
        )

        XCTAssertEqual(
            visibleFrame.maxY - targetFrame.maxY,
            FeaturePanelMetrics.panelTopInset
        )
    }
}
