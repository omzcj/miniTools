import AppKit
import SwiftUI

@MainActor
final class FeaturePanelSelectionModel: ObservableObject {
    @Published var selection: FeaturePanelKind

    init(selection: FeaturePanelKind) {
        self.selection = selection
    }
}

struct FeaturePanelView: View {
    @ObservedObject var selectionModel: FeaturePanelSelectionModel
    @ObservedObject var encodingViewModel: EncodingConversionPanelViewModel
    @ObservedObject var safariViewModel: SafariWindowPanelViewModel
    let onSelectPanel: (FeaturePanelKind) -> Void

    var body: some View {
        VStack(spacing: FeaturePanelMetrics.switcherContentSpacing) {
            panelSwitcher
            panelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .featurePanelSurface()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelSwitcher: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 8) {
                activePanelTitle
                panelButton(for: .encodingConversion)
                panelButton(for: .safariWindows)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: FeaturePanelMetrics.switcherHeight,
            maxHeight: FeaturePanelMetrics.switcherHeight
        )
    }

    private var activePanelTitle: some View {
        activePanelTitleContent(for: selectionModel.selection)
            .padding(.horizontal, 14)
            .frame(
                maxWidth: .infinity,
                minHeight: FeaturePanelMetrics.switcherHeight,
                maxHeight: FeaturePanelMetrics.switcherHeight,
                alignment: .leading
            )
            .featurePanelGlassControl(in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private func activePanelTitleContent(for kind: FeaturePanelKind) -> some View {
        HStack(spacing: 9) {
            panelIcon(for: kind)
                .frame(width: 17, height: 17)
                .foregroundStyle(Color.accentColor)

            Text(kind.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch selectionModel.selection {
        case .safariWindows:
            SafariWindowPanelView(viewModel: safariViewModel)
        case .encodingConversion:
            EncodingConversionPanelView(viewModel: encodingViewModel)
        }
    }

    private func panelButton(for kind: FeaturePanelKind) -> some View {
        let isSelected = selectionModel.selection == kind

        return Button {
            guard !isSelected else { return }
            onSelectPanel(kind)
        } label: {
            panelIcon(for: kind)
                .frame(width: 16, height: 16)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .featurePanelGlassControl(selected: isSelected, in: Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(isSelected ? "已选择" : "")
        .help(kind.title)
    }

    @ViewBuilder
    private func panelIcon(for kind: FeaturePanelKind) -> some View {
        switch kind {
        case .safariWindows:
            Image(systemName: "safari")
                .resizable()
                .scaledToFit()
        case .encodingConversion:
            if let image = AppArtwork.hammerTemplate {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: "hammer.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
