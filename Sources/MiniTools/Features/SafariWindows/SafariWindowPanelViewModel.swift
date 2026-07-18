import Foundation

@MainActor
final class SafariWindowPanelViewModel: ObservableObject {
    static let selectionKeys = Array("asdfqwerzxcvtgbyhnuiopl").map(String.init)

    @Published private(set) var windows: [SafariWindowItem] = []
    @Published var selectedWindowID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isActivating = false
    @Published private(set) var errorMessage: String?
    @Published var layout: SafariPanelLayout = .empty

    var onWindowCountChanged: ((Int) -> Void)?
    var onWindowActivated: (() -> Void)?
    var onCancel: (() -> Void)?

    private var loadingTask: Task<Void, Never>?
    private var activationTask: Task<Void, Never>?
    private var sessionGeneration = 0
    private let client: SafariWindowClient

    init(
        initialWindows: [SafariWindowItem] = [],
        client: SafariWindowClient = .live
    ) {
        windows = initialWindows
        selectedWindowID = initialWindows.first(where: \.wasActiveWindow)?.id ?? initialWindows.first?.id
        self.client = client
    }

    func beginSession() {
        sessionGeneration += 1
        load()
    }

    func endSession() {
        sessionGeneration += 1
        loadingTask?.cancel()
        activationTask?.cancel()
        loadingTask = nil
        activationTask = nil
        isLoading = false
        isActivating = false
    }

    private func load() {
        loadingTask?.cancel()
        isLoading = true
        isActivating = false
        errorMessage = nil
        let fetchWindows = client.fetchWindows
        let generation = sessionGeneration

        loadingTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try fetchWindows() }
            }.value
            guard let self,
                  !Task.isCancelled,
                  sessionGeneration == generation else {
                return
            }

            loadingTask = nil
            isLoading = false
            switch result {
            case let .success(items):
                windows = items
                selectedWindowID = items.first(where: \.wasActiveWindow)?.id ?? items.first?.id
                if items.isEmpty {
                    errorMessage = "Safari 未运行或当前没有浏览器窗口"
                }
                onWindowCountChanged?(items.count)

            case let .failure(error):
                windows = []
                selectedWindowID = nil
                errorMessage = error.localizedDescription
                onWindowCountChanged?(0)
            }
        }
    }

    func activateSelectedWindow() {
        guard !isActivating, let selectedWindowID else { return }
        isActivating = true
        errorMessage = nil
        let activateWindow = client.activateWindow
        let generation = sessionGeneration

        activationTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try activateWindow(selectedWindowID) }
            }.value
            guard let self,
                  !Task.isCancelled,
                  sessionGeneration == generation else {
                return
            }
            activationTask = nil
            isActivating = false
            switch result {
            case .success:
                onWindowActivated?()
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
    }

    func activateAllUngroupedWindows() {
        guard !isActivating else { return }
        let windowIDs = windows.filter { !$0.hasTabGroup }.map(\.id)
        guard !windowIDs.isEmpty else {
            errorMessage = "当前没有不属于标签页组的 Safari 窗口"
            return
        }

        isActivating = true
        errorMessage = nil
        let activateWindows = client.activateWindows
        let generation = sessionGeneration

        activationTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try activateWindows(windowIDs) }
            }.value
            guard let self,
                  !Task.isCancelled,
                  sessionGeneration == generation else {
                return
            }
            activationTask = nil
            isActivating = false
            switch result {
            case .success:
                onWindowActivated?()
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
    }

    func handleCommand(_ command: FeaturePanelCommand) -> Bool {
        switch command {
        case let .moveSelection(offset):
            moveSelection(by: offset)
            return true
        case .execute:
            activateSelectedWindow()
            return true
        case .cancel:
            onCancel?()
            return true
        case let .character(key):
            return handleSelectionKey(key)
        case .openSettings, .switchPanel, .directAction:
            return false
        }
    }

    func handleSelectionKey(_ key: String) -> Bool {
        if key == "m" {
            activateAllUngroupedWindows()
            return true
        }
        if key == "j" {
            moveSelection(by: 1)
            return true
        }
        if key == "k" {
            moveSelection(by: -1)
            return true
        }
        if let index = Self.selectionKeys.firstIndex(of: key), windows.indices.contains(index) {
            selectedWindowID = windows[index].id
            activateSelectedWindow()
            return true
        }
        return false
    }

    func shortcut(at index: Int) -> String? {
        Self.selectionKeys.indices.contains(index) ? Self.selectionKeys[index] : nil
    }

    private func moveSelection(by offset: Int) {
        guard !windows.isEmpty else { return }
        errorMessage = nil
        let current = windows.firstIndex(where: { $0.id == selectedWindowID }) ?? 0
        let next = min(max(current + offset, 0), windows.count - 1)
        selectedWindowID = windows[next].id
    }
}
