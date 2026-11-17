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

/// The five tabs: today's idea, the closet, the outfits, the diary and the tools.
struct RootView: View {
    @State private var tab: AppTab = Demo.tab ?? .today

    var body: some View {
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
            MoreView()
                .tabItem { Label("Strumenti", systemImage: "square.grid.2x2") }
                .tag(AppTab.more)
        }
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
