import SwiftUI

/// The dark palette shared by all of the user's apps; only the accent changes (here: violet, the shadow).
enum Theme {
    static let bg = Color(red: 15 / 255, green: 15 / 255, blue: 17 / 255)
    static let panel = Color(red: 28 / 255, green: 28 / 255, blue: 32 / 255)
    static let line = Color(red: 52 / 255, green: 52 / 255, blue: 60 / 255)
    static let input = Color(red: 38 / 255, green: 38 / 255, blue: 44 / 255)
    static let text = Color(red: 242 / 255, green: 242 / 255, blue: 246 / 255)
    static let sub = Color(red: 150 / 255, green: 150 / 255, blue: 162 / 255)
    static let good = Color(red: 74 / 255, green: 214 / 255, blue: 124 / 255)
    static let bad = Color(red: 240 / 255, green: 96 / 255, blue: 80 / 255)
    static let warn = Color(red: 255 / 255, green: 176 / 255, blue: 32 / 255)
    static let accent = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
    /// Behind the garment photos: a shade lighter than the panels, so dark clothes still stand out.
    static let photo = Color(red: 36 / 255, green: 36 / 255, blue: 42 / 255)
    /// Where a piece is shown: lit from above and darker at the edges, so the piece and the
    /// shadow under it stand out. The one place the app is not flat.
    static let stage = EllipticalGradient(
        colors: [Color(red: 52 / 255, green: 52 / 255, blue: 62 / 255), Color(red: 29 / 255, green: 29 / 255, blue: 34 / 255)],
        center: UnitPoint(x: 0.5, y: 0.34), startRadiusFraction: 0, endRadiusFraction: 0.78)
    /// The shadow a piece without background throws on the stage.
    static let shadow = Color.black.opacity(0.5)
}

/// The corners, from the biggest surface to the smallest.
enum Radius {
    static let stage: CGFloat = 22
    static let panel: CGFloat = 18
    static let control: CGFloat = 13
    static let thumb: CGFloat = 12
}

extension Font {
    /// The app's own voice: wide and heavy, for the date, the big numbers and the name of the app.
    /// What the user wrote (names of pieces and outfits) stays in the plain face.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, weight: .heavy).width(.expanded)
    }
}

extension View {
    /// The shadow of a piece cut out of its background, as if it hung in front of the stage.
    func pieceShadow(_ on: Bool = true, small: Bool = false) -> some View {
        shadow(color: on ? Theme.shadow : .clear, radius: small ? 4 : 10, x: 0, y: small ? 3 : 8)
    }
}

/// A rounded panel with a small uppercase title above it.
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
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(Theme.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer()
                    if let trailing { trailing }
                }
                .padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        }
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

/// The main action of a screen: full, lit from above, and it gives a little under the finger.
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
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color, in: shape)
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)))
                .foregroundStyle(Theme.bg)
                .shadow(color: color.opacity(enabled ? 0.3 : 0), radius: 12, x: 0, y: 6)
                .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// The other actions: a tint of the accent, no outline.
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
                .padding(.horizontal, 14)
                .background(color.opacity(configuration.isPressed ? 0.26 : 0.16), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .foregroundStyle(color)
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
            .padding(12)
            .background(Theme.input, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
            .background(Theme.bad.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
                Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            Text(value).font(.display(.title2)).monospacedDigit().foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(Theme.sub)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
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
