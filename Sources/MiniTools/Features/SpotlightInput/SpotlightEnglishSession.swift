import Foundation
import OSLog

struct ApplicationIdentity: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

@MainActor
final class SpotlightEnglishSession {
    private static let logger = Logger(
        subsystem: "com.omzcj.minitools",
        category: "SpotlightInput"
    )

    private let englishInputSources: EnglishInputSourceCoordinator
    private var originApplication: ApplicationIdentity?
    private(set) var isActive = false

    init(englishInputSources: EnglishInputSourceCoordinator) {
        self.englishInputSources = englishInputSources
    }

    func begin(originApplication: ApplicationIdentity?) {
        guard !isActive else { return }
        isActive = true

        let establishedRestorableOverride = englishInputSources.begin(for: .spotlight)
        self.originApplication = establishedRestorableOverride ? originApplication : nil
        Self.logger.debug(
            "Started Spotlight input session from \(Self.description(of: originApplication), privacy: .public); restoration tracked: \(establishedRestorableOverride)"
        )
    }

    func finish(destinationApplication: ApplicationIdentity?) {
        guard isActive else { return }
        let shouldRestore = originApplication != nil
            && destinationApplication == originApplication
        Self.logger.debug(
            "Finished Spotlight input session at \(Self.description(of: destinationApplication), privacy: .public); restore origin: \(shouldRestore)"
        )
        englishInputSources.end(
            for: .spotlight,
            behavior: shouldRestore ? .restoreIfUnchanged : .discardRestoration
        )
        reset()
    }

    func ensureEnglish() {
        guard isActive else { return }
        englishInputSources.ensureEnglish(for: .spotlight)
    }

    func stop() {
        guard isActive else { return }
        englishInputSources.end(for: .spotlight, behavior: .restoreIfUnchanged)
        reset()
    }

    private func reset() {
        isActive = false
        originApplication = nil
    }

    private static func description(of application: ApplicationIdentity?) -> String {
        guard let application else { return "unknown" }
        return "\(application.bundleIdentifier ?? "unknown") [\(application.processIdentifier)]"
    }
}
