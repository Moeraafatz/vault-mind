import SwiftUI
import VaultMindCore

public enum VaultTheme {
    public static let canvasTop = Color(red: 0.042, green: 0.046, blue: 0.082)
    public static let canvasBottom = Color(red: 0.018, green: 0.022, blue: 0.042)
    public static let cardSurface = Color.white.opacity(0.055)
    public static let cardBorder = Color.white.opacity(0.11)
    public static let cardBorderStrong = Color.white.opacity(0.18)

    public static let indigo = Color(red: 0.369, green: 0.361, blue: 0.902)   // #5E5CE6
    public static let mint = Color(red: 0.400, green: 0.831, blue: 0.812)     // #66D4CF
    public static let emerald = Color(red: 0.188, green: 0.820, blue: 0.345)  // #30D158
    public static let gold = Color(red: 1.000, green: 0.839, blue: 0.039)     // #FFD60A
    public static let rose = Color(red: 1.000, green: 0.271, blue: 0.227)     // #FF453A

    public static let textPrimary = Color.white.opacity(0.95)
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.42)

    public static func kindTint(_ kind: DocumentKind) -> Color {
        switch kind {
        case .pdf: return rose
        case .imageOCR: return gold
        case .markdown: return mint
        case .code: return indigo
        case .table: return emerald
        }
    }

    public static func formatBytes(_ bytes: Int64) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let val = Double(bytes)
        if val >= gb { return String(format: "%.2f GB", val / gb) }
        if val >= mb { return String(format: "%.1f MB", val / mb) }
        if val >= kb { return String(format: "%.0f KB", val / kb) }
        return "\(bytes) B"
    }
}

public struct VaultGlassCard<Content: View>: View {
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let borderColor: Color
    private let content: Content

    public init(
        padding: CGFloat = 11,
        cornerRadius: CGFloat = 13,
        borderColor: Color = VaultTheme.cardBorder,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VaultTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
            )
    }
}

public struct VaultTogglePill: View {
    public let isOn: Bool
    public let accent: Color
    public let action: () -> Void

    public init(isOn: Bool, accent: Color = VaultTheme.mint, action: @escaping () -> Void) {
        self.isOn = isOn
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? accent.opacity(0.88) : Color.white.opacity(0.14))
                    .frame(width: 34, height: 19)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75))
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}
