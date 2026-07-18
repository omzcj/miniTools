struct SafariWindowClient: Sendable {
    let fetchWindows: @Sendable () throws -> [SafariWindowItem]
    let activateWindow: @Sendable (String) throws -> Void
    let activateWindows: @Sendable ([String]) throws -> Void

    static let live = SafariWindowClient(
        fetchWindows: SafariWindowService.fetchWindows,
        activateWindow: SafariWindowService.activateWindow,
        activateWindows: SafariWindowService.activateWindows
    )
}
