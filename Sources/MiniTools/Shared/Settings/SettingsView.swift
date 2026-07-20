import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case featurePanel
    case inputSource
    case windowManagement
    case mouseBindings
    case cursorAnimation

    var id: Self { self }

    var title: String {
        switch self {
        case .featurePanel: "工具面板"
        case .inputSource: "输入法切换"
        case .windowManagement: "窗口管理"
        case .mouseBindings: "鼠标侧键"
        case .cursorAnimation: "定位动画"
        }
    }

    var subtitle: String {
        switch self {
        case .featurePanel:
            "配置统一面板的唤起方式与转换参数。"
        case .inputSource:
            "让 Spotlight 搜索使用英文，并保留系统的文稿输入法记忆。"
        case .windowManagement:
            "配置窗口布局、跨屏操作与全局快捷键。"
        case .mouseBindings:
            "为 Button 4、Button 5 分配点击和方向拖动动作。"
        case .cursorAnimation:
            "选择鼠标定位时轮换播放的视觉效果。"
        }
    }

    var systemImage: String {
        switch self {
        case .featurePanel: "hammer"
        case .inputSource: "character.cursor.ibeam"
        case .windowManagement: "macwindow"
        case .mouseBindings: "computermouse"
        case .cursorAnimation: "cursorarrow.rays"
        }
    }
}

struct SettingsSceneRoot: View {
    @ObservedObject var context: ApplicationContext

    var body: some View {
        if let shortcutCoordinator = context.shortcutCoordinator,
           let mouseBindingCoordinator = context.mouseBindingCoordinator {
            SettingsView(
                settings: context.settings,
                shortcutCoordinator: shortcutCoordinator,
                mouseBindingCoordinator: mouseBindingCoordinator,
                previewCursorHighlight: context.previewCursorHighlight
            )
        } else {
            ProgressView("正在载入设置…")
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcutCoordinator: GlobalShortcutCoordinator
    @ObservedObject var mouseBindingCoordinator: MouseBindingCoordinator
    let previewCursorHighlight: (CursorHighlightStyle) -> Void
    @State private var selectedCategory: SettingsCategory? = .featurePanel

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.title, systemImage: category.systemImage)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 240)
        } detail: {
            SettingsCategoryDetail(
                category: selectedCategory ?? .featurePanel,
                settings: settings,
                shortcutCoordinator: shortcutCoordinator,
                mouseBindingCoordinator: mouseBindingCoordinator,
                previewCursorHighlight: previewCursorHighlight
            )
            .id(selectedCategory)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 780, minHeight: 540)
    }
}

private struct SettingsCategoryDetail: View {
    let category: SettingsCategory
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcutCoordinator: GlobalShortcutCoordinator
    @ObservedObject var mouseBindingCoordinator: MouseBindingCoordinator
    let previewCursorHighlight: (CursorHighlightStyle) -> Void
    @State private var showsCompactTitle = false

    var body: some View {
        Form {
            Section {
                categoryHeader
            }

            switch category {
            case .featurePanel:
                featurePanelSettings
            case .inputSource:
                inputSourceSettings
            case .windowManagement:
                windowManagementSettings
            case .mouseBindings:
                MouseBindingSettingsView(
                    settings: settings,
                    coordinator: mouseBindingCoordinator
                )
            case .cursorAnimation:
                CursorAnimationSettingsView(
                    settings: settings,
                    preview: previewCursorHighlight
                )
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(showsCompactTitle ? category.title : "")
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 72
        } action: { _, isPastHeader in
            showsCompactTitle = isPastHeader
        }
    }

    private var categoryHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: category.systemImage)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 68, height: 68)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(category.title)
                .font(.system(size: 26, weight: .bold))

            Text(category.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var inputSourceSettings: some View {
        Section {
            Toggle(isOn: $settings.spotlightUsesEnglishInputSource) {
                settingsLabel(
                    title: "Spotlight 使用英文",
                    subtitle: "仅在搜索框获得焦点且当前不是英文时临时切换"
                )
            }
        } header: {
            Text("Spotlight")
        } footer: {
            Text(
                "直接关闭 Spotlight 时恢复原输入法；打开其他应用时由 macOS 的文稿输入法记忆接管。需要辅助功能权限。"
            )
        }
    }

    @ViewBuilder
    private var featurePanelSettings: some View {
        Section("唤起") {
            panelShortcutRow
        }

        Section("图片处理") {
            LabeledContent {
                HStack(spacing: 10) {
                    Slider(value: $settings.compressionQuality, in: 0.4...0.95, step: 0.05)
                        .frame(width: 170)
                    Text("\(Int(settings.compressionQuality * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            } label: {
                settingsLabel(
                    title: "JPEG 压缩质量",
                    subtitle: "用于“压缩图片”操作；质量越高，文件通常越大"
                )
            }
        }
    }

    @ViewBuilder
    private var windowManagementSettings: some View {
        Section("窗口布局") {
            ForEach(WindowControlCatalog.windowLayoutDescriptors) { descriptor in
                windowControlRow(descriptor)
            }
        }

        Section {
            ForEach(WindowControlCatalog.crossScreenDescriptors) { descriptor in
                windowControlRow(descriptor)
            }
        } header: {
            Text("跨屏操作")
        } footer: {
            Text("快捷键修改后立即生效。窗口操作需要辅助功能权限。")
        }
    }

    private func shortcutRow(
        title: String,
        subtitle: String,
        shortcut: KeyboardShortcut,
        error: String?,
        onChange: @escaping (KeyboardShortcut) -> Bool
    ) -> some View {
        LabeledContent {
            ShortcutRecorderView(shortcut: shortcut, onChange: onChange)
                .frame(width: 190, height: 28)
        } label: {
            settingsLabel(title: title, subtitle: subtitle, error: error)
        }
    }

    private var panelShortcutRow: some View {
        shortcutRow(
            title: "全局快捷键",
            subtitle: "打开上次使用的面板",
            shortcut: settings.panelShortcut,
            error: shortcutCoordinator.panelError,
            onChange: shortcutCoordinator.updatePanelShortcut
        )
    }

    private func windowControlRow(_ descriptor: WindowControlDescriptor) -> some View {
        LabeledContent {
            ShortcutRecorderView(
                shortcut: settings.windowControlShortcut(for: descriptor.id),
                onChange: { shortcut in
                    shortcutCoordinator.updateWindowControlShortcut(shortcut, for: descriptor.id)
                }
            )
            .frame(width: 190, height: 28)
        } label: {
            settingsLabel(
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                error: shortcutCoordinator.windowControlErrors[descriptor.id]
            )
        }
    }

    private func settingsLabel(
        title: String,
        subtitle: String,
        error: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }
}
