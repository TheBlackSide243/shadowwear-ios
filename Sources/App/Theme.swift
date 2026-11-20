import SwiftUI

/// The look of the app: indigo surfaces one on the other, a warm white for what matters, one orange
/// for what you can do. Surfaces and pictures have square corners and a thin outline; the things
/// you press (buttons, fields, filters) are pills. Everything is set in the monospaced face.
enum Theme {
    /// The page.
    static let bg = Color(red: 38 / 255, green: 38 / 255, blue: 66 / 255)
    /// A card on the page.
    static let panel = Color(red: 50 / 255, green: 50 / 255, blue: 86 / 255)
    /// Sunk into the page: where pieces are shown, where you type.
    static let deep = Color(red: 30 / 255, green: 30 / 255, blue: 54 / 255)
    /// The outline of every surface.
    static let line = Color.white.opacity(0.12)
    /// A control that is not the main one.
    static let input = Color(red: 42 / 255, green: 42 / 255, blue: 72 / 255)
    static let text = Color(red: 249 / 255, green: 246 / 255, blue: 240 / 255)
    static let sub = Color(red: 169 / 255, green: 171 / 255, blue: 187 / 255)
    static let good = Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255)
    static let bad = Color(red: 255 / 255, green: 107 / 255, blue: 129 / 255)
    /// Amber, so a warning is never mistaken for the orange of the buttons.
    static let warn = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
    static let accent = Color(red: 255 / 255, green: 122 / 255, blue: 46 / 255)
    static let photo = deep
    /// Where a piece is shown: the dark of the insets with a faint orange light behind the piece,
    /// so it and the shadow under it stand out.
    static let stage = EllipticalGradient(
        colors: [Color(red: 68 / 255, green: 46 / 255, blue: 54 / 255), deep],
        center: UnitPoint(x: 0.5, y: 0.42), startRadiusFraction: 0, endRadiusFraction: 0.7)
    /// The shadow a piece without background throws on the stage.
    static let shadow = Color.black.opacity(0.5)
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

    /// A card: the raised surface with its thin outline, square.
    func card(_ fill: Color = Theme.panel) -> some View {
        background(fill).overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
    }

    /// The box around a symbol: dark, with the outline in the accent.
    func iconBox() -> some View {
        background(Theme.deep).overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1))
    }

    /// Capitals pulled a little together, for the big words of a screen.
    func hero() -> some View {
        textCase(.uppercase).tracking(-0.6)
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
                .foregroundStyle(Theme.deep)
                .shadow(color: color.opacity(enabled ? 0.25 : 0), radius: 10, x: 0, y: 5)
                .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
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
                Text(error).font(.footnote).foregroundStyle(Theme.text).textSelection(.enabled)
                Spacer()
                Button { self.error = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.sub) }
                    .accessibilityLabel(Text("Chiudi"))
            }
            .padding(14)
            .background(Theme.bad.opacity(0.16))
            .overlay(Rectangle().strokeBorder(Theme.bad.opacity(0.5), lineWidth: 1))
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
