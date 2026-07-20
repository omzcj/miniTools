import Foundation
import OSLog

@MainActor
final class EnglishInputSourceCoordinator {
    private static let logger = Logger(
        subsystem: "com.omzcj.minitools",
        category: "InputSource"
    )
    enum Owner: Hashable {
        case encodingPanel
        case spotlight
    }

    enum EndBehavior {
        case restoreIfUnchanged
        case discardRestoration
    }

    private struct SessionState {
        let previousIdentifier: String?
        let selectedEnglishIdentifier: String?
    }

    private let currentProcessInputSources: InputSourceClient
    private let focusedApplicationInputSources: InputSourceClient
    private var sessions: [Owner: SessionState] = [:]

    init(
        inputSources: InputSourceClient? = nil,
        spotlightInputSources: InputSourceClient? = nil
    ) {
        currentProcessInputSources = inputSources ?? .currentProcess
        focusedApplicationInputSources = spotlightInputSources
            ?? inputSources
            ?? .focusedApplication
    }

    @discardableResult
    func begin(for owner: Owner) -> Bool {
        if let session = sessions[owner] {
            return session.previousIdentifier != nil
        }

        let inputSources = inputSources(for: owner)
        if let beginEnglishOverride = inputSources.beginEnglishOverride {
            guard let override = beginEnglishOverride() else {
                sessions[owner] = SessionState(
                    previousIdentifier: nil,
                    selectedEnglishIdentifier: nil
                )
                return false
            }
            sessions[owner] = SessionState(
                previousIdentifier: override.previousIdentifier,
                selectedEnglishIdentifier: override.selectedIdentifier
            )
        } else {
            guard
                let currentIdentifier = inputSources.currentIdentifier(),
                let englishIdentifier = inputSources.preferredEnglishIdentifier(),
                currentIdentifier != englishIdentifier,
                inputSources.select(englishIdentifier)
            else {
                sessions[owner] = SessionState(
                    previousIdentifier: nil,
                    selectedEnglishIdentifier: nil
                )
                return false
            }
            sessions[owner] = SessionState(
                previousIdentifier: currentIdentifier,
                selectedEnglishIdentifier: englishIdentifier
            )
        }
        Self.logger.debug("Applied temporary English input source for \(String(describing: owner))")
        return true
    }

    func end(for owner: Owner, behavior: EndBehavior = .restoreIfUnchanged) {
        guard let session = sessions.removeValue(forKey: owner) else { return }

        if behavior == .discardRestoration {
            Self.logger.debug("Discarded temporary input source restoration")
            return
        }
        restoreIfUnchanged(session, using: inputSources(for: owner))
    }

    func ensureEnglish(for owner: Owner) {
        guard
            let session = sessions[owner],
            let selectedEnglishIdentifier = session.selectedEnglishIdentifier
        else {
            return
        }
        _ = inputSources(for: owner).select(selectedEnglishIdentifier)
        Self.logger.debug("Reapplied temporary English input source")
    }

    func stop() {
        let activeSessions = sessions
        sessions.removeAll()
        for (owner, session) in activeSessions {
            restoreIfUnchanged(session, using: inputSources(for: owner))
        }
    }

    private func restoreIfUnchanged(
        _ session: SessionState,
        using inputSources: InputSourceClient
    ) {
        guard
            let previousIdentifier = session.previousIdentifier,
            let selectedEnglishIdentifier = session.selectedEnglishIdentifier,
            inputSources.currentIdentifier() == selectedEnglishIdentifier
        else {
            return
        }
        _ = inputSources.select(previousIdentifier)
        Self.logger.debug("Restored input source after temporary English session")
    }

    private func inputSources(for owner: Owner) -> InputSourceClient {
        switch owner {
        case .encodingPanel:
            currentProcessInputSources
        case .spotlight:
            focusedApplicationInputSources
        }
    }
}
