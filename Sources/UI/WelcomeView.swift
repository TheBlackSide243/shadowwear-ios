import SwiftUI

/// First launch: a few pages on what ShadowWear does, then the choice: the closet only on this
/// iPhone (no sign-in at all) or on the ShadowWear server. "Salta" goes straight to the choice,
/// and either can be changed later in Settings → Server.
/// From Settings → Info the same pages can be seen again, without the choice (`replay`).
struct WelcomeView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Only the pages, opened from Settings: the last button closes them.
    let replay: Bool
    /// Called once the choice is made (or the pages are closed, when replaying).
    let done: () -> Void
    @State private var page: Int
    @State private var connecting = ["newserver", "code"].contains(Demo.screen)
    /// After the choice: the AI step (where it runs, said for local or server).
    @State private var askingAI = Demo.screen == "aisetup"

    init(replay: Bool = false, done: @escaping () -> Void) {
        self.replay = replay
        self.done = done
        _page = State(initialValue: replay ? 0 : Self.demoPage)
    }

    /// The index of the choice (one past the pages), or of the last page when replaying.
    private var last: Int { replay ? IntroPage.all.count - 1 : IntroPage.all.count }

    var body: some View {
        if askingAI {
            NavigationStack {
                AISettingsView(firstRun: true, done: done)
            }
        } else {
            pages
        }
    }

    private var pages: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if replay {
                    Button("Chiudi", action: done)
                } else if page < last {
                    Button("Salta") { go(to: last) }
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.sub)
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                ForEach(IntroPage.all.indices, id: \.self) { i in
                    Fill { PageContent(page: IntroPage.all[i]) }
                        .tag(i)
                }
                if !replay {
                    Fill { choice }
                        .tag(IntroPage.all.count)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $connecting, onDismiss: {
            // Connected: on to the AI. Cancelled: back to the two choices.
            if sync.isOn { askingAI = true }
        }) {
            ServerConnectView()
        }
    }

    // MARK: - The choice

    private var choice: some View {
        VStack(spacing: 22) {
            Hero(symbol: "externaldrive", badge: "iphone")
            VStack(spacing: 8) {
                Text("Dove vuoi tenere il tuo armadio?")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text("Scegli adesso. Puoi cambiare idea quando vuoi da Impostazioni → Server.")
                    .foregroundStyle(Theme.sub)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Choice(icon: "iphone",
                       title: "Usa in locale",
                       detail: "L'armadio resta solo su questo iPhone. Nessun account e nessun login, funziona anche senza internet.") {
                    askingAI = true
                }
                Choice(icon: "server.rack",
                       title: "Usa un server",
                       detail: "Collega l'app al tuo server ShadowWear, con la password o con un codice del sito: l'armadio è uguale su iPhone, iPad e sul sito, e l'IA del server può descrivere i capi.") {
                    connecting = true
                }
            }
        }
    }

    // MARK: - Dots and the button below

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 7) {
                ForEach(0..<(last + 1), id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Theme.line)
                        .frame(width: i == page ? 22 : 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Pagina \(page + 1) di \(last + 1)"))

            if page < last {
                Button { go(to: page + 1) } label: { Text("Avanti") }
                    .buttonStyle(PrimaryButtonStyle())
            } else if replay {
                Button(action: done) { Text("Fine") }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                // The two choices are the buttons here: keep the footer the same height.
                Color.clear.frame(height: 50)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .animation(reduceMotion ? nil : .snappy, value: page)
    }

    private func go(to index: Int) {
        if reduceMotion {
            page = index
        } else {
            withAnimation(.snappy) { page = index }
        }
    }

    /// Demo screens: `intro`, `intro2` … are the pages, `welcome` (and the server sheets) the choice.
    private static var demoPage: Int {
        guard let screen = Demo.screen else { return 0 }
        if screen.hasPrefix("intro") {
            let n = Int(screen.dropFirst("intro".count)) ?? 1
            return min(max(n - 1, 0), IntroPage.all.count - 1)
        }
        return IntroPage.all.count
    }
}

// MARK: - The pages

/// One page of the introduction: a picture, a title, a sentence and three points.
struct IntroPage {
    struct Point {
        let symbol: String
        let title: String
        let detail: String
    }

    let symbol: String
    let badge: String?
    let title: String
    let text: String
    let points: [Point]

    static let all: [IntroPage] = [
        IntroPage(symbol: "hanger", badge: nil,
                  title: "Benvenuto in ShadowWear",
                  text: "Il tuo armadio in tasca: i vestiti in foto, un'idea di cosa mettere ogni giorno e il ricordo di cosa hai indossato.",
                  points: [
                      Point(symbol: "photo.on.rectangle", title: "Tutto in foto", detail: "Ogni capo con la sua foto, ritagliato dallo sfondo."),
                      Point(symbol: "sun.max", title: "Cosa mettere oggi", detail: "Un'idea al giorno, in base al meteo e ai tuoi capi."),
                      Point(symbol: "lock", title: "I dati restano tuoi", detail: "Sull'iPhone o sul tuo server: nessun altro li vede."),
                  ]),
        IntroPage(symbol: "camera", badge: "scissors",
                  title: "Fotografa i tuoi capi",
                  text: "Scatta una foto o prendile dalla galleria, anche tante insieme: ogni foto diventa un capo.",
                  points: [
                      Point(symbol: "scissors", title: "Sfondo tolto da solo", detail: "Il capo viene ritagliato, la foto originale resta."),
                      Point(symbol: "paintpalette", title: "Colori riconosciuti", detail: "L'app trova i colori principali di ogni capo."),
                      Point(symbol: "tag", title: "Tipo suggerito", detail: "Maglia, pantaloni, scarpe… tu devi solo controllare."),
                  ]),
        IntroPage(symbol: "sun.max", badge: "sparkles",
                  title: "Un'idea ogni mattina",
                  text: "In Oggi trovi il meteo della tua città e un outfit pensato per la giornata. Non ti convince? Tocca «Un'altra idea».",
                  points: [
                      Point(symbol: "thermometer.medium", title: "Adatto al tempo", detail: "Capi caldi o leggeri, e un avviso se piove."),
                      Point(symbol: "circle.lefthalf.filled", title: "Colori che stanno bene", detail: "Abbinamenti scelti tra i capi che hai."),
                      Point(symbol: "clock.arrow.circlepath", title: "Sempre diverso", detail: "Tiene conto di cosa hai messo negli ultimi giorni."),
                  ]),
        IntroPage(symbol: "square.stack.3d.up", badge: "calendar",
                  title: "Outfit e diario",
                  text: "Salva le combinazioni che ti piacciono e segna cosa indossi: col tempo scopri quali capi usi davvero.",
                  points: [
                      Point(symbol: "briefcase", title: "Un outfit per ogni occasione", detail: "Tutti i giorni, lavoro, sport, sera, casa."),
                      Point(symbol: "calendar", title: "Il mese in foto", detail: "Il diario mostra cosa hai messo giorno per giorno."),
                      Point(symbol: "chart.bar", title: "Qualche numero", detail: "I capi più messi e quelli dimenticati nell'armadio."),
                  ]),
        IntroPage(symbol: "sparkles", badge: "suitcase",
                  title: "L'IA e gli strumenti",
                  text: "Se vuoi, un'intelligenza artificiale ti aiuta: quella del server, Apple Intelligence o un tuo servizio. E nella scheda Strumenti c'è tutto il resto.",
                  points: [
                      Point(symbol: "bubble.left.and.text.bubble.right", title: "Stylist e selfie", detail: "Chiedi cosa mettere, o fatti una foto e l'IA riconosce i tuoi capi."),
                      Point(symbol: "washer", title: "Lavaggi e stagioni", detail: "Cosa lavare, cosa mettere via e cosa non metti mai."),
                      Point(symbol: "suitcase", title: "Valigia e acquisti", detail: "La valigia col meteo del posto e la lista di cose da comprare con i prezzi."),
                  ]),
    ]
}

private struct PageContent: View {
    let page: IntroPage

    var body: some View {
        VStack(spacing: 22) {
            Hero(symbol: page.symbol, badge: page.badge)
            VStack(spacing: 8) {
                Text(LocalizedStringKey(page.title))
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(LocalizedStringKey(page.text))
                    .foregroundStyle(Theme.sub)
            }
            .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.points, id: \.title) { point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 36, height: 36)
                            .iconBox()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(point.title))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text)
                            Text(LocalizedStringKey(point.detail))
                                .font(.subheadline)
                                .foregroundStyle(Theme.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
            .card()
        }
    }
}

/// The picture at the top of a page: a big symbol on a tile, with a small one on its corner.
private struct Hero: View {
    let symbol: String
    let badge: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 104, height: 104)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                )
            if let badge {
                Image(systemName: badge)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent, in: Circle())
                    .overlay(Circle().stroke(Theme.bg, lineWidth: 4))
                    .offset(x: 12, y: 12)
            }
        }
        .padding(.bottom, badge == nil ? 0 : 12)
        .accessibilityHidden(true)
    }
}

/// A page that scrolls when it does not fit (small iPhones, big text) and sits in the middle when it does.
private struct Fill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// One of the two big buttons of the choice.
private struct Choice: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .iconBox()
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(LocalizedStringKey(detail))
                        .font(.subheadline)
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.sub)
                    .padding(.top, 12)
            }
            .padding(16)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
