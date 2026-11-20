import SwiftUI

/// The colors of one look of the app. Everything else (the shapes, the faces, the spacing) is the
/// same in every look.
struct Palette: Identifiable, Equatable {
    let id: String
    /// Its name in Settings.
    let name: String
    /// Light text on dark surfaces; false for the one look in daylight colors.
    let dark: Bool
    /// The page.
    let bg: Color
    /// A card on the page.
    let panel: Color
    /// Sunk into the page: where you type, the boxes of the symbols.
    let deep: Color
    /// A control that is not the main one.
    let input: Color
    /// The outline of every surface.
    let line: Color
    let text: Color
    let sub: Color
    /// What you can do: the main button, the chosen filter, the symbols.
    let accent: Color
    /// What is written on the accent.
    let onAccent: Color
    let good: Color
    let bad: Color
    /// Never the same hue as the accent, so a warning is not mistaken for a button.
    let warn: Color
    /// Behind a piece: lighter than the page in the middle, so that dark clothes stand out, and
    /// without a color of its own, so that the colors of the clothes stay true.
    let stageCenter: Color
    let stageEdge: Color
    /// How dark the shadow under a piece is.
    let shadow: Double

    private static func c(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    /// Indigo and orange: the look the app is born with.
    static let power = Palette(
        id: "power", name: "Power", dark: true,
        bg: c(0x262642), panel: c(0x323256), deep: c(0x1e1e36), input: c(0x2a2a48), line: .white.opacity(0.12),
        text: c(0xf9f6f0), sub: c(0xa9abbb), accent: c(0xff7a2e), onAccent: c(0x1e1e36),
        good: c(0x34d399), bad: c(0xff6b81), warn: c(0xfbbf24),
        stageCenter: c(0x5c5c82), stageEdge: c(0x3a3a60), shadow: 0.5)
    /// Almost black with violet: the look of the first versions.
    static let ombra = Palette(
        id: "ombra", name: "Ombra", dark: true,
        bg: c(0x0f0f11), panel: c(0x1c1c20), deep: c(0x131316), input: c(0x26262c), line: .white.opacity(0.10),
        text: c(0xf2f2f6), sub: c(0x9c9ca8), accent: c(0xa78bfa), onAccent: c(0x15121f),
        good: c(0x4ad67c), bad: c(0xf06050), warn: c(0xffb020),
        stageCenter: c(0x4c4c56), stageEdge: c(0x2b2b31), shadow: 0.55)
    /// Dark green with lime.
    static let bosco = Palette(
        id: "bosco", name: "Bosco", dark: true,
        bg: c(0x12211c), panel: c(0x1b302a), deep: c(0x0c1814), input: c(0x172923), line: .white.opacity(0.11),
        text: c(0xf3f5ee), sub: c(0x9fb0a6), accent: c(0xa3e635), onAccent: c(0x12211c),
        good: c(0x34d399), bad: c(0xff6b81), warn: c(0xfbbf24),
        stageCenter: c(0x4f6259), stageEdge: c(0x2c3f37), shadow: 0.5)
    /// Deep blue with sky blue.
    static let oceano = Palette(
        id: "oceano", name: "Oceano", dark: true,
        bg: c(0x0e2233), panel: c(0x163349), deep: c(0x0a1926), input: c(0x122b3f), line: .white.opacity(0.12),
        text: c(0xf1f6fa), sub: c(0x9db2c4), accent: c(0x38bdf8), onAccent: c(0x0a1926),
        good: c(0x34d399), bad: c(0xff6b81), warn: c(0xfbbf24),
        stageCenter: c(0x4d667d), stageEdge: c(0x284458), shadow: 0.5)
    /// Daylight: white cards on a cool gray page, dark ink, a deep orange.
    static let carta = Palette(
        id: "carta", name: "Carta", dark: false,
        bg: c(0xf1f2f6), panel: c(0xffffff), deep: c(0xe6e8ef), input: c(0xeceef3), line: .black.opacity(0.10),
        text: c(0x1d1e2c), sub: c(0x5f6274), accent: c(0xd9480f), onAccent: c(0xffffff),
        good: c(0x0f9d6b), bad: c(0xd6336c), warn: c(0xa16207),
        stageCenter: c(0xdfe2ea), stageEdge: c(0xc4c9d6), shadow: 0.3)

    static let all = [power, ombra, bosco, oceano, carta]

    static func named(_ id: String?) -> Palette {
        all.first { $0.id == id } ?? power
    }
}

/// The look in use. The screens read its colors through `Theme`, and are drawn again when it changes.
@Observable final class Look {
    static let shared = Look()

    private(set) var palette: Palette

    private init() {
        // Also `-theme <id>` when the app is started, as the README pictures are taken.
        palette = Palette.named(UserDefaults.standard.string(forKey: Prefs.theme))
    }

    func choose(_ palette: Palette) {
        UserDefaults.standard.set(palette.id, forKey: Prefs.theme)
        self.palette = palette
    }
}

/// The look of the app: surfaces one on the other, one color for what you can do, in the colors of
/// the look chosen in Settings. Surfaces and pictures have a thin outline and round corners; the
/// things you press (buttons, fields, filters) are pills. Titles, numbers and labels are set in
/// the monospaced face; what is to be read at length in the plain one (see `prose()`).
enum Theme {
    private static var p: Palette { Look.shared.palette }

    static var isDark: Bool { p.dark }
    static var bg: Color { p.bg }
    static var panel: Color { p.panel }
    static var deep: Color { p.deep }
    static var line: Color { p.line }
    static var input: Color { p.input }
    static var text: Color { p.text }
    static var sub: Color { p.sub }
    static var good: Color { p.good }
    static var bad: Color { p.bad }
    static var warn: Color { p.warn }
    static var accent: Color { p.accent }
    static var onAccent: Color { p.onAccent }
    /// Where a piece is shown: lit in the middle, a shade darker at the edges.
    static var stage: EllipticalGradient {
        EllipticalGradient(colors: [p.stageCenter, p.stageEdge],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadiusFraction: 0, endRadiusFraction: 0.75)
    }
    /// The shadow a piece without background throws on the stage.
    static var shadow: Color { Color.black.opacity(p.shadow) }
    /// The shape of a surface (a card, a stage, a big picture): round corners.
    static let round = RoundedRectangle(cornerRadius: 18, style: .continuous)
    /// The same for small things: thumbnails, the boxes of the symbols, the days of the calendar.
    static let roundSmall = RoundedRectangle(cornerRadius: 11, style: .continuous)
}

extension Font {
    /// The big words of a screen (the date, the month, the big numbers): to be shown in capitals.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced, weight: .semibold)
    }
}

extension View {
    /// The shadow of a piece cut out of its background, as if it hung in front of the stage.
    func pieceShadow(_ on: Bool = true, small: Bool = false) -> some View {
        shadow(color: on ? Theme.shadow : .clear, radius: small ? 4 : 10, x: 0, y: small ? 3 : 8)
    }

    /// A card: the raised surface with its thin outline.
    func card(_ fill: Color = Theme.panel) -> some View {
        background(fill, in: Theme.round).overlay(Theme.round.strokeBorder(Theme.line, lineWidth: 1))
    }

    /// The box around a symbol: dark, with the outline in the accent. `big` for the ones that
    /// stand alone on a screen.
    func iconBox(big: Bool = false) -> some View {
        let shape = big ? Theme.round : Theme.roundSmall
        return background(Theme.deep, in: shape).overlay(shape.strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1))
    }

    /// Capitals pulled a little together, for the big words of a screen.
    func hero() -> some View {
        textCase(.uppercase).tracking(-0.6)
    }

    /// What is to be read at length (a description, an answer of the stylist, a note): in the
    /// plain face, which reads better in sentences than the monospaced one.
    func prose() -> some View {
        // `nil` takes the monospaced design of the app off; `.default` would leave it on.
        fontDesign(nil)
    }

}

/// The whole app in the look chosen: its accent on what the system draws, its face, and light or
/// dark for the bars and the sheets. Its body reads the look, so it is applied again on a change.
struct Dressed: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Theme.accent)
            .fontDesign(.monospaced)
            .preferredColorScheme(Theme.isDark ? .dark : .light)
    }
}

/// The looks of the app in Settings, each as a small picture of itself: its page, a card, its accent.
struct ThemePicker: View {
    var body: some View {
        let current = Look.shared.palette
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 12) {
            ForEach(Palette.all) { palette in
                let selected = palette.id == current.id
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { Look.shared.choose(palette) }
                } label: {
                    VStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.panel)
                                .frame(height: 24)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(palette.text).frame(width: 28, height: 4).padding(.leading, 7)
                                }
                            Capsule().fill(palette.accent).frame(width: 38, height: 11)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.bg, in: Theme.roundSmall)
                        .overlay(Theme.roundSmall.strokeBorder(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1))
                        HStack(spacing: 4) {
                            if selected { Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(Theme.accent) }
                            Text(LocalizedStringKey(palette.name)).font(.caption.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Theme.text : Theme.sub)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey(palette.name)))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: current.id)
    }
}

extension Theme {
    /// The monospaced face in the segmented pickers too, which the system draws. The titles in the
    /// bars and the names of the tabs stay in the system's face: they are its own furniture.
    /// Called once, before the first screen is made.
    @MainActor static func dressBars() {
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)], for: .normal)
    }
}

/// A card with its title inside, at the top.
struct Panel<Content: View>: View {
    var title: String?
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer()
                    if let trailing { trailing }
                }
            }
            VStack(alignment: .leading, spacing: 12) { content }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// A key/value row.
struct InfoRow: View {
    let label: String
    let value: String
    var color: Color = Theme.text

    init(_ label: String, _ value: String, color: Color = Theme.text) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(label)).foregroundStyle(Theme.sub)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(color).multilineTextAlignment(.trailing).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
    }
}

/// The main action of a screen: the orange pill. It gives a little under the finger.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, color: color)
    }

    private struct Face: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(color, in: Capsule())
                .foregroundStyle(Theme.onAccent)
                .shadow(color: color.opacity(enabled ? 0.25 : 0), radius: 10, x: 0, y: 5)
                .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// A card that opens something (a piece, an outfit in a grid): it gives a little under the finger.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// The other actions: a quiet pill with the outline of the surfaces. In another color (red for
/// what deletes) the words take that color.
struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, color: color)
    }

    private struct Face: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(configuration.isPressed ? Theme.panel : Theme.input, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                .foregroundStyle(color == Theme.accent ? Theme.text : color)
                .opacity(enabled ? 1 : 0.4)
        }
    }
}

/// A text field in the dark input style.
struct Field: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var secure = false
    var keyboard: UIKeyboardType = .default

    /// Passwords, addresses and user names: no capitals or corrections.
    private var plain: Bool { secure || ([.URL, .emailAddress, .asciiCapable] as [UIKeyboardType]).contains(keyboard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title)).font(.caption.weight(.semibold)).foregroundStyle(Theme.sub)
            Group {
                if secure { SecureField(LocalizedStringKey(prompt), text: $text) } else { TextField(LocalizedStringKey(prompt), text: $text) }
            }
            .keyboardType(keyboard)
            .textInputAutocapitalization(plain ? .never : .sentences)
            .autocorrectionDisabled(plain)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Theme.deep, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        }
    }
}

/// A red banner for the last error, dismissable.
struct ErrorBanner: View {
    @Binding var error: String?

    var body: some View {
        if let error {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
                Text(error).prose().font(.footnote).foregroundStyle(Theme.text).textSelection(.enabled)
                Spacer()
                Button { self.error = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.sub) }
                    .accessibilityLabel(Text("Chiudi"))
            }
            .padding(14)
            .background(Theme.bad.opacity(0.16), in: Theme.round)
            .overlay(Theme.round.strokeBorder(Theme.bad.opacity(0.5), lineWidth: 1))
        }
    }
}

/// One number of the closet or the diary, big, with what it counts under it.
struct StatTile: View {
    let value: String
    let label: String
    var symbol: String?
    var color: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .iconBox()
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
            }
            Text(value).font(.display(.title2)).monospacedDigit().foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: value)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(Theme.sub)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct StatusDot: View {
    let color: Color
    var body: some View { Circle().fill(color).frame(width: 9, height: 9) }
}

/// A progress bar in the accent color.
struct Bar: View {
    let value: Double
    var color: Color = Theme.accent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.input)
                Capsule().fill(color).frame(width: max(0, min(1, value)) * g.size.width)
                    .animation(.snappy(duration: 0.4), value: value)
            }
        }
        .frame(height: 7)
    }
}

extension View {
    /// Dark scroll background used by every screen.
    func screen() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
