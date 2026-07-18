import CoreGraphics

enum PointerMover {
    static func moveToNextScreen() async throws -> CGPoint {
        let geometries = await WindowGeometry.screenGeometries()
        return try await Task.detached(priority: .userInitiated) {
            guard let pointerLocation = CGEvent(source: nil)?.location else {
                throw WindowLayoutError.cannotReadPointerPosition
            }

            let target = try targetLocation(
                from: pointerLocation,
                geometries: geometries
            )
            let result = CGWarpMouseCursorPosition(target)
            guard result == .success else {
                throw WindowLayoutError.cannotMovePointer(result)
            }
            return target
        }.value
    }

    static func targetLocation(
        from pointerLocation: CGPoint,
        geometries: [WindowLayoutScreenGeometry]
    ) throws -> CGPoint {
        guard !geometries.isEmpty else { throw WindowLayoutError.notEnoughScreens }

        // With one display there is nowhere to move, but returning the current
        // position lets the caller continue into the cursor-highlight animation.
        guard geometries.count > 1 else { return pointerLocation }

        let currentIndex = WindowGeometry.screenIndex(
            containing: pointerLocation,
            geometries: geometries
        )
        let nextIndex = (currentIndex + 1) % geometries.count
        return CGPoint(
            x: round(geometries[nextIndex].visibleFrame.midX),
            y: round(geometries[nextIndex].visibleFrame.midY)
        )
    }
}
