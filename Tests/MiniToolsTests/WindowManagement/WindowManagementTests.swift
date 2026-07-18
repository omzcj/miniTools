import CoreGraphics
import XCTest
@testable import MiniTools

final class WindowManagementTests: XCTestCase {
    func testDetectsVisibleApplicationWithNoAXWindowRoleAsInvalid() {
        XCTAssertTrue(
            WindowAccessibilityHealth.isInvalid(
                candidateRoles: [kAXApplicationRole as String],
                hasVisibleWindow: true
            )
        )
        XCTAssertFalse(
            WindowAccessibilityHealth.isInvalid(
                candidateRoles: [kAXWindowRole as String],
                hasVisibleWindow: true
            )
        )
        XCTAssertFalse(
            WindowAccessibilityHealth.isInvalid(
                candidateRoles: [],
                hasVisibleWindow: false
            )
        )
    }

    func testInvalidAccessibilityStateExplainsHowToRecover() {
        XCTAssertEqual(
            WindowLayoutError.invalidAccessibilityWindowState("Sublime Text")
                .localizedDescription,
            "Sublime Text 的辅助功能窗口状态异常，请重启该应用后再试"
        )
    }

    @MainActor
    func testSharinganUsesCircularShadowAndClippedArtwork() throws {
        let view = SharinganCursorHighlightView(
            style: .sharinganThreeTomoe,
            frame: CGRect(origin: .zero, size: SharinganCursorHighlightView.canvasSize)
        )

        view.startAnimation()

        let eye = try XCTUnwrap(view.layer?.sublayers?.first(where: { $0.cornerRadius > 0 }))
        XCTAssertEqual(eye.bounds.width, SharinganCursorHighlightView.eyeDiameter)
        XCTAssertNotNil(eye.shadowPath)

        let clip = try XCTUnwrap(eye.sublayers?.first)
        XCTAssertTrue(clip.masksToBounds)
        XCTAssertEqual(clip.cornerRadius, SharinganCursorHighlightView.eyeDiameter / 2)
        XCTAssertNotNil(clip.sublayers?.first?.contents)

        let maximumAuraDiameter = (SharinganCursorHighlightView.eyeDiameter + 18) * 1.6
        XCTAssertGreaterThan(view.bounds.width, maximumAuraDiameter)
    }

    @MainActor
    func testEveryConfiguredSharinganStyleHasRenderableArtwork() {
        let styles = CursorHighlightStyle.basicSharinganStyles
            + CursorHighlightStyle.mangekyoStyles
            + CursorHighlightStyle.evolvedDojutsuStyles

        XCTAssertTrue(CursorHighlightStyle.allCases.contains(.mangekyoHikari))
        XCTAssertTrue(CursorHighlightStyle.mangekyoStyles.contains(.mangekyoHikari))
        for style in styles {
            XCTAssertNotNil(
                SharinganArtwork.renderedArtwork(for: style),
                "Missing or invalid artwork for \(style.rawValue)"
            )
        }
    }

    @MainActor
    func testCatalogMatchesRequestedShortcutOrder() {
        XCTAssertEqual(
            WindowControlCatalog.layoutCommands.map(\.id),
            [.upperLeft, .upperRight, .lowerLeft, .lowerRight, .left, .right,
             .horizontalHalves, .verticalThirds, .maximize]
        )
        XCTAssertTrue(WindowControlCatalog.layoutCommands.allSatisfy { $0.frames.count == 2 })
        XCTAssertEqual(WindowControlCatalog.descriptors.count, 12)
        XCTAssertEqual(
            WindowControlCatalog.windowLayoutDescriptors.map(\.id),
            [.upperLeft, .upperRight, .lowerLeft, .lowerRight, .left, .right,
             .horizontalHalves, .verticalThirds, .maximize, .centerWindow]
        )
        XCTAssertEqual(
            WindowControlCatalog.crossScreenDescriptors.map(\.id),
            [.moveWindowToNextScreen, .movePointerToNextScreen]
        )
    }

    @MainActor
    func testBuildsTargetFrameInsideVisibleScreen() {
        let visible = CGRect(x: 100, y: 40, width: 1200, height: 900)
        let frame = WindowGeometry.targetFrame(
            for: UnitWindowFrame(2.0 / 3.0, 0.5, 1.0 / 3.0, 0.5),
            in: visible
        )
        XCTAssertEqual(frame, CGRect(x: 900, y: 490, width: 400, height: 450))
    }

    @MainActor
    func testCyclesToSecondFrameAndBack() {
        let first = CGRect(x: 0, y: 0, width: 600, height: 800)
        let second = CGRect(x: 0, y: 0, width: 400, height: 800)

        XCTAssertEqual(
            WindowGeometry.nextTarget(currentFrame: first, candidates: [first, second]),
            second
        )
        XCTAssertEqual(
            WindowGeometry.nextTarget(currentFrame: second, candidates: [first, second]),
            first
        )
        XCTAssertEqual(
            WindowGeometry.nextTarget(
                currentFrame: CGRect(x: 50, y: 50, width: 500, height: 500),
                candidates: [first, second]
            ),
            first
        )
    }

    @MainActor
    func testConvertsAppKitCoordinatesToAccessibilityCoordinates() {
        let appKitRect = CGRect(x: -1000, y: 1080, width: 1000, height: 800)
        let converted = WindowGeometry.appKitToAccessibility(appKitRect, primaryScreenMaxY: 1080)
        XCTAssertEqual(converted, CGRect(x: -1000, y: -800, width: 1000, height: 800))
    }

    @MainActor
    func testMovesWindowToNextScreenPreservingRelativePosition() {
        let source = CGRect(x: 0, y: 20, width: 1200, height: 800)
        let destination = CGRect(x: 1200, y: 40, width: 1600, height: 1000)
        let current = CGRect(x: 300, y: 220, width: 600, height: 400)

        let moved = WindowGeometry.frameByMoving(current, from: source, to: destination)
        XCTAssertEqual(moved, CGRect(x: 1700, y: 340, width: 600, height: 400))
    }

    @MainActor
    func testCentersWindowWithoutChangingSize() {
        let visible = CGRect(x: 100, y: 50, width: 1400, height: 900)
        let current = CGRect(x: 0, y: 0, width: 600, height: 400)
        XCTAssertEqual(
            WindowGeometry.centeredFrame(current, in: visible),
            CGRect(x: 500, y: 300, width: 600, height: 400)
        )
    }

    @MainActor
    func testFindsScreenContainingPoint() {
        let screens = [
            WindowLayoutScreenGeometry(
                fullFrame: CGRect(x: -1000, y: 0, width: 1000, height: 800),
                visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 760)
            ),
            WindowLayoutScreenGeometry(
                fullFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                visibleFrame: CGRect(x: 0, y: 20, width: 1200, height: 840)
            )
        ]
        XCTAssertEqual(
            WindowGeometry.screenIndex(containing: CGPoint(x: -500, y: 300), geometries: screens),
            0
        )
        XCTAssertEqual(
            WindowGeometry.screenIndex(containing: CGPoint(x: 800, y: 300), geometries: screens),
            1
        )
    }

    func testPointerMoveContinuesAtCurrentLocationWithOneScreen() throws {
        let pointer = CGPoint(x: 420, y: 260)
        let screen = WindowLayoutScreenGeometry(
            fullFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            visibleFrame: CGRect(x: 0, y: 20, width: 1200, height: 840)
        )

        XCTAssertEqual(
            try PointerMover.targetLocation(from: pointer, geometries: [screen]),
            pointer
        )
    }

    func testPointerMoveTargetsTheCenterOfTheNextScreen() throws {
        let screens = [
            WindowLayoutScreenGeometry(
                fullFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                visibleFrame: CGRect(x: 0, y: 20, width: 1200, height: 840)
            ),
            WindowLayoutScreenGeometry(
                fullFrame: CGRect(x: 1200, y: 0, width: 1600, height: 1000),
                visibleFrame: CGRect(x: 1200, y: 40, width: 1600, height: 920)
            )
        ]

        XCTAssertEqual(
            try PointerMover.targetLocation(
                from: CGPoint(x: 600, y: 450),
                geometries: screens
            ),
            CGPoint(x: 2000, y: 500)
        )
    }
}
