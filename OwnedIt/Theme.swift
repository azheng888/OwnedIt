import SwiftUI
import UIKit

// MARK: - Design System ("E": Cursor's structure + Granola's warmth)
//
// • Warm paper background; cards are a slightly lighter surface with a 1pt border, no shadows.
// • Ink (near-black) is the only accent: primary buttons, selection, toggles, progress.
//   The only other colors are semantic: amber for warnings, red for critical.
// • Type: SF Pro only — one typeface everywhere (titles, headers, body, fields, numbers).
//   Hierarchy comes from size and weight, never from a different design (no serif, no mono).
//   Numbers use tabular digits.
// • One art style: neutral rounded-square tiles with a secondary-gray glyph, or the item's photo.
// • Motion: short critically damped springs, press-scale 0.97, respects Reduce Motion.

enum Theme {
    // Surfaces
    static let background = Color(light: 0xF5F2EB, dark: 0x151412)
    static let surface = Color(light: 0xFCFBF8, dark: 0x1E1D1A)
    static let surfaceMuted = Color(light: 0xECE8DE, dark: 0x2A2824)
    static let hairline = Color(light: 0xE4DFD4, dark: 0x34322D)
    static let divider = Color(light: 0xEEEAE1, dark: 0x2A2824)

    // Text
    static let ink = Color(light: 0x1F1D19, dark: 0xF2EFE8)
    static let secondaryText = Color(light: 0x77715F, dark: 0xA39D8C)
    static let tertiaryText = Color(light: 0xA39D8C, dark: 0x6E6A5F)

    // Accent & semantics
    static let accent = ink
    static let positive = ink
    static let warning = Color(light: 0xA3520F, dark: 0xE0A04A)
    static let critical = Color(light: 0xB3261E, dark: 0xF2827A)
    /// Text/icons drawn on top of an ink-filled control.
    static let onAccent = Color(light: 0xFCFBF8, dark: 0x151412)

    // Shape
    static let cardRadius: CGFloat = 14
    static let photoRadius: CGFloat = 16
    static let spacing: CGFloat = 16

    /// Applies global UIKit appearance (navigation bar titles) once at launch.
    static func applyAppearance() {
        func titleFont(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
        }
        let ink = UIColor(Theme.ink)
        let largeTitle: [NSAttributedString.Key: Any] = [.font: titleFont(.largeTitle, size: 34, weight: .bold), .foregroundColor: ink]
        let inlineTitle: [NSAttributedString.Key: Any] = [.font: titleFont(.headline, size: 17, weight: .semibold), .foregroundColor: ink]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.largeTitleTextAttributes = largeTitle
        standard.titleTextAttributes = inlineTitle

        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.largeTitleTextAttributes = largeTitle
        edge.titleTextAttributes = inlineTitle

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        bar.scrollEdgeAppearance = edge
    }
}

// MARK: - Typography

extension Font {
    /// Large figures (totals). SF Pro, tabular digits.
    static func hero(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }
}

extension View {
    /// Section header above a card: SF Pro semibold, ink.
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }

    /// Secondary metadata text.
    func secondaryText() -> some View {
        foregroundStyle(Theme.secondaryText)
    }
}

// MARK: - Motion

enum Motion {
    /// Default UI spring: quick, no overshoot, interruptible.
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 1)
    /// For elements entering the screen.
    static let enter = Animation.spring(response: 0.35, dampingFraction: 0.9)
    /// Press feedback must be near-instant.
    static let press = Animation.spring(response: 0.18, dampingFraction: 1)
}

/// Scale-on-press feedback. Subtle (0.97).
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Primary call-to-action: full-width ink pill.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.ink.opacity(isEnabled ? 1 : 0.35), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// Entrance: fade + slight scale, staggered by index.
private struct AppearEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible || reduceMotion ? 1 : 0.98)
            .onAppear {
                guard !visible else { return }
                let delay = reduceMotion ? 0 : Double(min(index, 6)) * 0.035
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.enter.delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func appearEffect(index: Int = 0) -> some View { modifier(AppearEffect(index: index)) }
}

// MARK: - Surfaces

extension View {
    /// Standard card: surface fill, 1pt border, 14pt continuous corners. No shadow.
    /// `tint` is for semantic emphasis only (warning/critical).
    func card(padding: CGFloat = Theme.spacing, tint: Color? = nil) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill((tint ?? .clear).opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(tint.map { $0.opacity(0.35) } ?? Theme.hairline, lineWidth: 1)
            )
    }

    /// Lists and forms on the paper background, rows on the card surface.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    func themedScreen() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Row styling inside a themed List.
    func themedRow() -> some View {
        self
            .listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.divider)
    }
}

/// The single icon treatment: neutral rounded square, secondary glyph.
/// Pass a semantic color (warning/critical) only when the icon carries meaning.
struct IconTile: View {
    let systemName: String
    var color: Color = Theme.secondaryText
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Section header row: title + optional trailing accessory (e.g. a total).
struct CardHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).sectionHeader()
            Spacer()
            trailing
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }
}

extension CardHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - Color helpers

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
