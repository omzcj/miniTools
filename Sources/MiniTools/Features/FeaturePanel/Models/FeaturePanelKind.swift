enum FeaturePanelKind: String, Codable, Hashable, Sendable {
    case encodingConversion
    case safariWindows

    var title: String {
        switch self {
        case .encodingConversion:
            "编码与转换"
        case .safariWindows:
            "Safari 窗口"
        }
    }
}
