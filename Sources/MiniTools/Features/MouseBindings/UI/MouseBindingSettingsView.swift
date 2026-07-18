import SwiftUI

struct MouseBindingSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var coordinator: MouseBindingCoordinator

    var body: some View {
        Group {
            Section("手势识别") {
                LabeledContent {
                    HStack(spacing: 10) {
                        Slider(
                            value: Binding(
                                get: { settings.mouseDragThresholdRatio },
                                set: { ratio in
                                    settings.updateMouseDragThresholdRatio(ratio)
                                }
                            ),
                            in: MouseGestureConfiguration.dragThresholdRatioRange,
                            step: MouseGestureConfiguration.dragThresholdRatioStep
                        )
                        .frame(width: 170)

                        Text(
                            settings.mouseDragThresholdRatio,
                            format: .percent.precision(.fractionLength(1))
                        )
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("拖动触发比例")
                            .font(.system(size: 13, weight: .medium))
                        Text("横向按屏幕宽度、纵向按屏幕高度计算")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(MouseSideButton.allCases) { button in
                Section {
                    ForEach(MouseButtonGesture.clickGestures) { gesture in
                        bindingRow(button: button, gesture: gesture)
                    }
                    ForEach(MouseButtonGesture.dragGestures) { gesture in
                        bindingRow(button: button, gesture: gesture)
                    }
                } header: {
                    Text(button.title)
                }
            }
        }
    }

    private func bindingRow(
        button: MouseSideButton,
        gesture: MouseButtonGesture
    ) -> some View {
        LabeledContent {
            Picker(
                "为\(button.title)的\(gesture.title)分配功能",
                selection: Binding<AppCommand?>(
                    get: {
                        coordinator.command(for: button, gesture: gesture)
                    },
                    set: { command in
                        coordinator.updateCommand(
                            command,
                            for: button,
                            gesture: gesture
                        )
                    }
                )
            ) {
                Text("无动作")
                    .tag(nil as AppCommand?)
                ForEach(AppCommandCatalog.sections) { section in
                    Section(section.title) {
                        ForEach(section.commands) { command in
                            Label(command.title, systemImage: command.systemImage)
                                .tag(command as AppCommand?)
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 230)
        } label: {
            Label(gesture.title, systemImage: gesture.systemImage)
                .foregroundStyle(.primary)
        }
    }
}
