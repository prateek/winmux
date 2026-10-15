import AppKit
import SwiftUI

struct LensTheme: Equatable, Sendable {
    let isDark: Bool
    static let dark = LensTheme(isDark: true)
    static let light = LensTheme(isDark: false)

    @MainActor
    static func resolve(_ appearance: String?, systemIsDark: () -> Bool) -> Self {
        switch appearance {
            case "dark": .dark
            case "light": .light
            default: systemIsDark() ? .dark : .light
        }
    }

    @MainActor
    static var systemIsDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var nsAppearance: NSAppearance { NSAppearance(named: isDark ? .darkAqua : .aqua)! }
    var panelFill: Color { isDark ? Color(red: 30 / 255, green: 32 / 255, blue: 38 / 255).opacity(0.62) : Color(red: 236 / 255, green: 238 / 255, blue: 243 / 255).opacity(0.74) }
    var panelLine: Color { isDark ? .white.opacity(GlassToken.borderOpacity) : .black.opacity(0.12) }
    var text: Color { isDark ? .white : Color(chromeHex: "16181d") }
    var searchText: Color { isDark ? .white.opacity(GlassToken.textPrimary) : text }
    var secondaryText: Color { isDark ? .white.opacity(0.62) : .black.opacity(0.55) }
    var selectionRing: Color { .accentColor }
    var selectionPlate: Color { selectionRing.opacity(isDark ? 0.26 : 0.2) }
    var chip: Color { isDark ? .white.opacity(0.16) : .black.opacity(0.1) }
    var miniatureScrim: Color { isDark ? .black : Color(chromeHex: "e8eaf0") }
    var peekPlate: Color { isDark ? Color(white: 34 / 255) : Color(red: 236 / 255, green: 238 / 255, blue: 243 / 255) }
    var peekLabel: Color { isDark ? Color(red: 20 / 255, green: 22 / 255, blue: 28 / 255).opacity(0.86) : panelFill }

    func ink(_ darkOpacity: Double) -> Color { isDark ? .white.opacity(darkOpacity) : (darkOpacity == 1 ? text : secondaryText) }
    func fill(_ darkOpacity: Double) -> Color { isDark ? .white.opacity(darkOpacity) : .black.opacity(0.1) }
    func line(_ darkOpacity: Double) -> Color { isDark ? .white.opacity(darkOpacity) : .black.opacity(0.12) }
    func badgePlate(_ darkOpacity: Double) -> Color { isDark ? .black.opacity(darkOpacity) : chip }
}

private struct LensThemeKey: EnvironmentKey {
    static let defaultValue = LensTheme.dark
}

extension EnvironmentValues {
    var lensTheme: LensTheme {
        get { self[LensThemeKey.self] }
        set { self[LensThemeKey.self] = newValue }
    }
}

struct LensPanelSurface<S: Shape>: View {
    @Environment(\.lensTheme) private var theme
    let shape: S
    var body: some View {
        if theme.isDark {
            GlassSurface(shape: shape, style: config.workspaceSidebar.chromeStyle,
                         solidColor: config.workspaceSidebar.resolvedSolidChromeColor)
        } else {
            ZStack {
                MiniatureBackdrop(material: .underWindowBackground)
                shape.fill(theme.panelFill)
                shape.stroke(theme.panelLine, lineWidth: StrokeToken.hairline)
            }
            .clipShape(shape)
        }
    }
}
