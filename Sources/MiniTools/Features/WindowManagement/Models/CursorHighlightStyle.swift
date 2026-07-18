import Foundation

enum CursorHighlightStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case spectrumFlow
    case siriFluid

    case sharinganOneTomoe
    case sharinganTwoTomoe
    case sharinganThreeTomoe

    case mangekyoIndra
    case mangekyoMadara
    case mangekyoIzuna
    case mangekyoItachi
    case mangekyoObito
    case mangekyoShisui
    case mangekyoSasuke
    case mangekyoFugaku
    case mangekyoShin
    case mangekyoSarada
    case mangekyoRai
    case mangekyoBaru
    case mangekyoNaka
    case mangekyoNaori
    case mangekyoHikari

    case eternalMadara
    case eternalSasuke
    case rinneSharingan
    case sasukeRinnegan

    var id: Self { self }

    var title: String {
        switch self {
        case .spectrumFlow: "炫彩流光"
        case .siriFluid: "Siri 灵动"
        case .sharinganOneTomoe: "一勾玉写轮眼"
        case .sharinganTwoTomoe: "二勾玉写轮眼"
        case .sharinganThreeTomoe: "三勾玉写轮眼"
        case .mangekyoIndra: "因陀罗"
        case .mangekyoMadara: "宇智波斑"
        case .mangekyoIzuna: "宇智波泉奈"
        case .mangekyoItachi: "宇智波鼬"
        case .mangekyoObito: "带土 / 卡卡西"
        case .mangekyoShisui: "宇智波止水"
        case .mangekyoSasuke: "宇智波佐助"
        case .mangekyoFugaku: "宇智波富岳（动画）"
        case .mangekyoShin: "宇智波信"
        case .mangekyoSarada: "宇智波佐良娜"
        case .mangekyoRai: "宇智波雷（动画）"
        case .mangekyoBaru: "宇智波巴鲁（动画）"
        case .mangekyoNaka: "宇智波那卡（动画）"
        case .mangekyoNaori: "宇智波治里（动画）"
        case .mangekyoHikari: "宇智波光 / 无名（游戏）"
        case .eternalMadara: "斑 · 永恒万花筒"
        case .eternalSasuke: "佐助 · 永恒万花筒"
        case .rinneSharingan: "轮回写轮眼"
        case .sasukeRinnegan: "佐助 · 六勾玉轮回眼"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .spectrumFlow:
            "环形流光与轨道光点"
        case .siriFluid:
            "会呼吸、融合和变形的彩色光团"
        case .sharinganOneTomoe, .sharinganTwoTomoe, .sharinganThreeTomoe:
            "基础写轮眼纹样"
        case .eternalMadara, .eternalSasuke:
            "永恒万花筒写轮眼纹样"
        case .rinneSharingan, .sasukeRinnegan:
            "轮回系瞳术纹样"
        default:
            "万花筒写轮眼纹样"
        }
    }

    static let ambientStyles: [Self] = [
        .spectrumFlow, .siriFluid
    ]

    static let basicSharinganStyles: [Self] = [
        .sharinganOneTomoe, .sharinganTwoTomoe, .sharinganThreeTomoe
    ]

    static let mangekyoStyles: [Self] = [
        .mangekyoIndra,
        .mangekyoMadara,
        .mangekyoIzuna,
        .mangekyoItachi,
        .mangekyoObito,
        .mangekyoShisui,
        .mangekyoSasuke,
        .mangekyoFugaku,
        .mangekyoShin,
        .mangekyoSarada,
        .mangekyoRai,
        .mangekyoBaru,
        .mangekyoNaka,
        .mangekyoNaori,
        .mangekyoHikari
    ]

    static let evolvedDojutsuStyles: [Self] = [
        .eternalMadara, .eternalSasuke, .rinneSharingan, .sasukeRinnegan
    ]

    static let allCases = ambientStyles
        + basicSharinganStyles
        + mangekyoStyles
        + evolvedDojutsuStyles
}
