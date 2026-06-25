import SwiftUI

// MARK: - Color tokens (from assistant.pen design variables)

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        case 6: // RRGGBB
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum AurisColor {
    static let bgWindow     = Color(hex: "#0A0E1A")
    static let bgSidebar    = Color(hex: "#0C1222")
    static let bgPanel      = Color(hex: "#0E1526")
    static let bgElevated   = Color(hex: "#16213A")
    static let bgHover      = Color(hex: "#1C2A47")
    static let border       = Color(hex: "#1F2C49")
    static let borderSubtle = Color(hex: "#172138")
    static let textPrimary  = Color(hex: "#ECF1FA")
    static let textSecondary = Color(hex: "#94A3B8")
    static let textMuted    = Color(hex: "#5B6A86")
    static let accent       = Color(hex: "#3B82F6")
    static let accent2      = Color(hex: "#B07CF6")
    static let accentBright = Color(hex: "#60A5FA")
    static let accentCyan   = Color(hex: "#43A5FF")
    static let accentDim    = Color(hex: "#1E40AF")
    static let danger       = Color(hex: "#F87171")
    static let success      = Color(hex: "#34D399")
    static let warn         = Color(hex: "#FBBF24")
}

// MARK: - Brand gradient

extension LinearGradient {
    /// Brand gradient: #43A5FF -> #8E83F5 -> #C887F2
    static let auris = LinearGradient(
        stops: [
            .init(color: Color(hex: "#43A5FF"), location: 0),
            .init(color: Color(hex: "#8E83F5"), location: 0.55),
            .init(color: Color(hex: "#C887F2"), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

enum AurisFont {
    /// UI font (Inter if bundled, else system).
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if isInstalled("Inter") {
            return .custom("Inter", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    /// Monospace font (JetBrains Mono if bundled, else system mono).
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if isInstalled("JetBrains Mono") {
            return .custom("JetBrains Mono", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    private static func isInstalled(_ family: String) -> Bool {
        #if canImport(AppKit)
        return NSFontManager.shared.availableFontFamilies.contains(family)
        #else
        return false
        #endif
    }
}

// MARK: - Pill button style (brand gradient)

struct GradientButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 11
    var fontSize: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AurisFont.ui(fontSize, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(LinearGradient.auris, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Subtle bordered "ghost" pill button (e.g. Microfone / Áudio do sistema).
struct GhostButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AurisFont.ui(13, .medium))
            .foregroundStyle(AurisColor.textSecondary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(AurisColor.bgElevated, in: Capsule())
            .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
