import SwiftUI

struct CursorAnimationSettingsView: View {
    @ObservedObject var settings: AppSettings
    let preview: (CursorHighlightStyle) -> Void

    var body: some View {
        Group {
            Section("通用光效") {
                ForEach(CursorHighlightStyle.ambientStyles) { style in
                    styleRow(style)
                }
            }

            Section("基础写轮眼") {
                ForEach(CursorHighlightStyle.basicSharinganStyles) { style in
                    styleRow(style)
                }
            }

            Section("万花筒写轮眼") {
                ForEach(CursorHighlightStyle.mangekyoStyles) { style in
                    styleRow(style)
                }
            }

            Section("进阶瞳术") {
                ForEach(CursorHighlightStyle.evolvedDojutsuStyles) { style in
                    styleRow(style)
                }
            }
        }
    }

    private func styleRow(_ style: CursorHighlightStyle) -> some View {
        LabeledContent {
            HStack(spacing: 10) {
                Button("预览", systemImage: "play.fill") {
                    preview(style)
                }
                .controlSize(.small)
                .help("在当前鼠标位置预览“\(style.title)”")

                Toggle(
                    "启用 \(style.title)",
                    isOn: Binding(
                        get: { settings.isCursorHighlightStyleEnabled(style) },
                        set: { isEnabled in
                            settings.updateCursorHighlightStyle(style, isEnabled: isEnabled)
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(style.title)
                    .font(.system(size: 13, weight: .medium))
                Text(style.accessibilityDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
