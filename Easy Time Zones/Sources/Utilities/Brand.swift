import SwiftUI

enum Brand {
    static let primary = Color.accentColor
    static let secondary = Color(NSColor.secondaryLabelColor)
    static let background = Color(NSColor.windowBackgroundColor)
    static let panel = Color(NSColor.controlBackgroundColor).opacity(0.92)
    static let panelBorder = Color.black.opacity(0.08)
    static let separator = Color(NSColor.separatorColor).opacity(0.65)
    static let rowHighlight = Color.accentColor.opacity(0.12)
    static let rowPressed = Color.accentColor.opacity(0.18)
    static let softText = Color.secondary
    static let success = Color.green
    static let warning = Color.orange

    enum Typography {
        static let hero = Font.system(size: 28, weight: .bold, design: .default)
        static let heading = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let mono = Font.body.monospacedDigit()
    }

    static let accentGradient = LinearGradient(
        colors: [primary.opacity(0.95), secondary.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let inputBackground = Color(NSColor.textBackgroundColor).opacity(0.95)
    static let inputBorder = Color.black.opacity(0.08)
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Brand.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Brand.panelBorder, lineWidth: 1)
            )
    }
}

struct InputSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Brand.inputBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Brand.inputBorder, lineWidth: 1)
            )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .liquidPanel()
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }

    func cardSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }

    func inputSurface() -> some View {
        modifier(InputSurface())
    }

    @ViewBuilder
    func liquidPanel(cornerRadius: CGFloat = 28) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Brand.panelBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
    }
}
