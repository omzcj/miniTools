import XCTest
@testable import MiniTools

final class SpotlightInputSourceTests: XCTestCase {
    @MainActor
    func testAlreadyEnglishDoesNotCreateRestoreWork() {
        let inputSources = FakeInputSources(current: "english", english: "english")
        let coordinator = EnglishInputSourceCoordinator(inputSources: inputSources.client)
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        session.begin(originApplication: .appA)
        session.finish(destinationApplication: .appA)

        XCTAssertTrue(inputSources.selections.isEmpty)
        XCTAssertEqual(inputSources.current, "english")
    }

    @MainActor
    func testClosingSpotlightBackToOriginRestoresPreviousInputSource() {
        let inputSources = FakeInputSources(current: "chinese", english: "english")
        let coordinator = EnglishInputSourceCoordinator(inputSources: inputSources.client)
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        session.begin(originApplication: .appA)
        session.finish(destinationApplication: .appA)

        XCTAssertEqual(inputSources.selections, ["english", "chinese"])
        XCTAssertEqual(inputSources.current, "chinese")
    }

    @MainActor
    func testOpeningAnotherApplicationDiscardsPreviousRestoration() {
        let inputSources = FakeInputSources(current: "chinese", english: "english")
        let coordinator = EnglishInputSourceCoordinator(inputSources: inputSources.client)
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        session.begin(originApplication: .appA)
        session.finish(destinationApplication: .appB)

        XCTAssertEqual(inputSources.selections, ["english"])
        XCTAssertEqual(inputSources.current, "english")
    }

    @MainActor
    func testExternalInputSourceChangeIsNeverOverwrittenDuringRestore() {
        let inputSources = FakeInputSources(current: "chinese", english: "english")
        let coordinator = EnglishInputSourceCoordinator(inputSources: inputSources.client)
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        session.begin(originApplication: .appA)
        inputSources.current = "japanese"
        session.finish(destinationApplication: .appA)

        XCTAssertEqual(inputSources.selections, ["english"])
        XCTAssertEqual(inputSources.current, "japanese")
    }

    @MainActor
    func testEncodingPanelAndSpotlightKeepIndependentInputContexts() {
        let encodingInputSources = FakeInputSources(current: "chinese", english: "english")
        let spotlightInputSources = FakeInputSources(current: "chinese", english: "english")
        let coordinator = EnglishInputSourceCoordinator(
            inputSources: encodingInputSources.client,
            spotlightInputSources: spotlightInputSources.client
        )
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        XCTAssertTrue(coordinator.begin(for: .encodingPanel))
        session.begin(originApplication: .appA)
        coordinator.end(for: .encodingPanel)
        XCTAssertEqual(encodingInputSources.selections, ["english", "chinese"])
        XCTAssertEqual(spotlightInputSources.current, "english")

        session.finish(destinationApplication: .appA)

        XCTAssertEqual(spotlightInputSources.selections, ["english", "chinese"])
        XCTAssertEqual(spotlightInputSources.current, "chinese")
    }

    @MainActor
    func testLaunchingAnotherApplicationDiscardsOnlySpotlightRestoration() {
        let encodingInputSources = FakeInputSources(current: "chinese", english: "english")
        let spotlightInputSources = FakeInputSources(current: "chinese", english: "english")
        let coordinator = EnglishInputSourceCoordinator(
            inputSources: encodingInputSources.client,
            spotlightInputSources: spotlightInputSources.client
        )
        let session = SpotlightEnglishSession(englishInputSources: coordinator)

        XCTAssertTrue(coordinator.begin(for: .encodingPanel))
        session.begin(originApplication: .appA)
        session.finish(destinationApplication: .appB)
        coordinator.end(for: .encodingPanel)

        XCTAssertEqual(encodingInputSources.selections, ["english", "chinese"])
        XCTAssertEqual(spotlightInputSources.selections, ["english"])
        XCTAssertEqual(spotlightInputSources.current, "english")
    }
}

@MainActor
private final class FakeInputSources {
    var current: String?
    let english: String?
    var selections: [String] = []

    init(current: String?, english: String?) {
        self.current = current
        self.english = english
    }

    var client: InputSourceClient {
        InputSourceClient(
            currentIdentifier: { [weak self] in self?.current },
            preferredEnglishIdentifier: { [weak self] in self?.english },
            select: { [weak self] identifier in
                guard let self else { return false }
                selections.append(identifier)
                current = identifier
                return true
            }
        )
    }
}

private extension ApplicationIdentity {
    static let appA = ApplicationIdentity(
        processIdentifier: 101,
        bundleIdentifier: "example.app-a"
    )
    static let appB = ApplicationIdentity(
        processIdentifier: 202,
        bundleIdentifier: "example.app-b"
    )
}
