import SwiftUI

enum AppTab: Hashable {
    case today, closet, outfits, diary, more
}

/// Where a link inside a tab goes: an outfit or a piece. Both are UUIDs, hence the wrapper.
enum AppRoute: Hashable {
    case outfit(Outfit.ID)
    case item(Item.ID)
}

extension View {
    /// The screens every tab can open.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .outfit(let id): OutfitDetailView(id: id)
            case .item(let id): ItemDetailView(id: id)
            }
        }
    }
}

/// The five tabs: today's idea, the closet, the outfits, the diary and the tools; and the side
/// menu (☰ at the top left) with every section, things to buy and the numbers among them.
struct RootView: View {
    @State private var tab: AppTab = Demo.tab ?? .today
    /// The tools open on the Strumenti tab: the side menu opens To buy and Statistics there.
    @State private var morePath: [MoreView.Tool] = Demo.moreTool.map { [$0] } ?? []
    @State private var menuOpen = Demo.screen == "menu"
    @State private var showSettings = false

    var body: some View {
        tabs
            .environment(\.openSideMenu, { menuOpen = true })
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    if menuOpen {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture { menuOpen = false }
                            .accessibilityLabel(Text("Chiudi il menu"))
                            .accessibilityAddTraits(.isButton)
                            .transition(.opacity)
                        SideMenu(current: current, go: go)
                            .gesture(DragGesture().onEnded { if $0.translation.width < -60 { menuOpen = false } })
                            .transition(.move(edge: .leading))
                    }
                }
                .animation(.snappy(duration: 0.25), value: menuOpen)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// The entry of the side menu for what is on screen.
    private var current: SideMenuEntry {
        switch tab {
        case .today: .today
        case .closet: .closet
        case .outfits: .outfits
        case .diary: .diary
        case .more:
            switch morePath.first {
            case .wishlist?: .wishlist
            case .stats?: .stats
            default: .tools
            }
        }
    }

    private func go(_ entry: SideMenuEntry) {
        menuOpen = false
        switch entry {
        case .today: tab = .today
        case .closet: tab = .closet
        case .outfits: tab = .outfits
        case .diary: tab = .diary
        case .wishlist: tab = .more; morePath = [.wishlist]
        case .stats: tab = .more; morePath = [.stats]
        case .tools: tab = .more; morePath = []
        case .settings: showSettings = true
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            TodayView(goToCloset: { tab = .closet })
                .tabItem { Label("Oggi", systemImage: "sun.max") }
                .tag(AppTab.today)
            ClosetView()
                .tabItem { Label("Armadio", systemImage: "hanger") }
                .tag(AppTab.closet)
            OutfitsView()
                .tabItem { Label("Outfit", systemImage: "square.stack.3d.up") }
                .tag(AppTab.outfits)
            DiaryView()
                .tabItem { Label("Diario", systemImage: "calendar") }
                .tag(AppTab.diary)
            MoreView(path: $morePath)
                .tabItem { Label("Strumenti", systemImage: "square.grid.2x2") }
                .tag(AppTab.more)
        }
    }
}

extension EnvironmentValues {
    /// Opens the side menu of the app.
    @Entry var openSideMenu: () -> Void = {}
}

/// The ☰ button at the top left of the main screens.
struct SideMenuButton: View {
    @Environment(\.openSideMenu) private var open

    var body: some View {
        Button { open() } label: { Label("Menu", systemImage: "line.3.horizontal") }
    }
}

extension View {
    /// The ☰ button, on the first screen of a tab.
    func sideMenuButton() -> some View {
        toolbar { ToolbarItem(placement: .topBarLeading) { SideMenuButton() } }
    }
}

enum SideMenuEntry: Hashable {
    case today, closet, outfits, diary, wishlist, stats, tools, settings

    var title: LocalizedStringKey {
        switch self {
        case .today: "Oggi"
        case .closet: "Armadio"
        case .outfits: "Outfit"
        case .diary: "Diario"
        case .wishlist: "Cosa comprare"
        case .stats: "Statistiche"
        case .tools: "Strumenti"
        case .settings: "Impostazioni"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .closet: "hanger"
        case .outfits: "square.stack.3d.up"
        case .diary: "calendar"
        case .wishlist: "cart"
        case .stats: "chart.bar"
        case .tools: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }
}

/// The side menu, like the sidebar of the site: every section of the app.
struct SideMenu: View {
    @Environment(Closet.self) private var closet
    let current: SideMenuEntry
    let go: (SideMenuEntry) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("SW")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("ShadowWear").font(.title3.bold()).foregroundStyle(Theme.text)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                row(.today)
                row(.closet, count: closet.items.count)
                row(.outfits, count: closet.outfits.count)
                row(.diary)
                Divider().overlay(Theme.line).padding(.vertical, 8)
                row(.wishlist, count: closet.wishes.filter { !$0.bought }.count)
                row(.stats)
                row(.tools)
                Divider().overlay(Theme.line).padding(.vertical, 8)
                row(.settings)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .frame(width: 290)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel.ignoresSafeArea())
        .overlay(alignment: .trailing) { Theme.line.frame(width: 1).ignoresSafeArea() }
    }

    private func row(_ entry: SideMenuEntry, count: Int = 0) -> some View {
        let selected = entry == current
        return Button { go(entry) } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.symbol).frame(width: 24)
                Text(entry.title)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)").font(.caption).foregroundStyle(Theme.sub)
                }
            }
            .font(.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Theme.accent : Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(selected ? Theme.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The cover of a piece, without background when it has one.
struct PieceImage: View {
    @Environment(Closet.self) private var closet
    let item: Item
    var thumbnail = true

    var body: some View {
        if let photo = item.photos.first, let image = closet.image(of: photo, thumbnail: thumbnail) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: photo.usesCutout ? 0 : 8, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: item.category.symbol)
                .font(.title2)
                .foregroundStyle(Theme.sub)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The pieces of an outfit laid out flat: what goes on the body in a column (top, dress, bottom),
/// coat, accessories, bag and shoes in a narrower one beside it.
struct OutfitCollage: View {
    let items: [Item]
    var spacing: CGFloat = 8
    var thumbnail = true

    private static let order: [Category] = [.top, .dress, .bottom, .outerwear, .accessory, .bag, .shoes, .other]
    private static let worn: Set<Category> = [.top, .dress, .bottom]

    var body: some View {
        let sorted = items.sorted { (Self.order.firstIndex(of: $0.category) ?? 9) < (Self.order.firstIndex(of: $1.category) ?? 9) }
        let main = sorted.filter { Self.worn.contains($0.category) }
        let side = sorted.filter { !Self.worn.contains($0.category) }
        GeometryReader { g in
            HStack(spacing: spacing) {
                if !main.isEmpty {
                    column(main)
                        .frame(width: side.isEmpty ? g.size.width : (g.size.width - spacing) * 0.62)
                }
                if !side.isEmpty {
                    column(side).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(spacing + 4)
        .background(Theme.photo)
        .overlay {
            if items.isEmpty {
                Image(systemName: "square.stack.3d.up").font(.largeTitle).foregroundStyle(Theme.sub)
            }
        }
    }

    private func column(_ pieces: [Item]) -> some View {
        VStack(spacing: spacing) {
            ForEach(pieces) { piece in
                PieceImage(item: piece, thumbnail: thumbnail)
            }
        }
    }
}
