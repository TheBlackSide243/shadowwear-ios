import SwiftUI

/// The saved outfits as a grid of collages, with the occasions as filters.
struct OutfitsView: View {
    @Environment(Closet.self) private var closet
    @State private var occasion: Occasion?
    @State private var favoritesOnly = false
    @State private var composing: OutfitDraft?
    @State private var path: [AppRoute] = []

    private var shown: [Outfit] {
        closet.outfits
            .filter { (occasion == nil || $0.occasion == occasion) && (!favoritesOnly || $0.favorite) }
            .sorted { $0.created > $1.created }
    }

    var body: some View {
        @Bindable var closet = closet
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ErrorBanner(error: $closet.error)
                    if closet.outfits.isEmpty {
                        EmptyOutfits(canCompose: !closet.items.isEmpty) { composing = OutfitDraft() }
                    } else {
                        occasionChips
                        if shown.isEmpty {
                            Text("Nessun outfit corrisponde.")
                                .foregroundStyle(Theme.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 12)], spacing: 12) {
                                ForEach(shown) { outfit in
                                    NavigationLink(value: AppRoute.outfit(outfit.id)) { OutfitCard(outfit: outfit) }
                                        .buttonStyle(.plain)
                                        .contextMenu { menu(outfit) }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .sideMenuButton()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !closet.outfits.isEmpty {
                        Button { favoritesOnly.toggle() } label: {
                            Image(systemName: favoritesOnly ? "star.fill" : "star")
                        }
                        .accessibilityLabel(Text("Solo preferiti"))
                    }
                    Button { composing = OutfitDraft() } label: { Image(systemName: "plus") }
                        .disabled(closet.items.isEmpty)
                        .accessibilityLabel(Text("Nuovo outfit"))
                }
            }
            .appDestinations()
        }
        .sheet(item: $composing) { draft in
            OutfitEditor(draft: draft) { saved in
                composing = nil
                if let saved { path = [.outfit(saved)] }
            }
        }
        .task { showDemoScreen() }
    }

    private func showDemoScreen() {
        switch Demo.screen {
        case "outfit": if let first = shown.first { path = [.outfit(first.id)] }
        case "compose": composing = OutfitDraft(outfit: closet.outfits.first ?? Outfit(name: "", items: []))
        default: break
        }
    }

    private var occasionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: String(localized: "Tutti"), count: closet.outfits.count, selected: occasion == nil) { occasion = nil }
                ForEach(Occasion.allCases.filter { o in closet.outfits.contains { $0.occasion == o } }) { o in
                    Chip(text: o.label, systemImage: o.symbol, count: closet.outfits.filter { $0.occasion == o }.count,
                         selected: occasion == o) {
                        occasion = occasion == o ? nil : o
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
        .clipped()
    }

    @ViewBuilder private func menu(_ outfit: Outfit) -> some View {
        Button {
            closet.wear(outfit)
        } label: { Label("L'ho messo oggi", systemImage: "checkmark.circle") }
        Button {
            closet.toggleFavoriteOutfit(outfit.id)
        } label: {
            Label(LocalizedStringKey(outfit.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti"),
                  systemImage: outfit.favorite ? "star.slash" : "star")
        }
        Button(role: .destructive) {
            closet.deleteOutfit(outfit.id)
        } label: { Label("Elimina", systemImage: "trash") }
    }
}

/// An outfit in the grid: the collage, its name and occasion.
struct OutfitCard: View {
    @Environment(Closet.self) private var closet
    let outfit: Outfit

    var body: some View {
        let pieces = closet.pieces(of: outfit)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                OutfitCollage(items: pieces, spacing: 6)
                if outfit.favorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.accent)
                        .padding(7)
                        .background(Theme.bg.opacity(0.7), in: Circle())
                        .padding(8)
                }
            }
            .aspectRatio(0.82, contentMode: .fit)
            .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                HStack(spacing: 5) {
                    if let occasion = outfit.occasion {
                        Image(systemName: occasion.symbol).font(.caption2)
                        Text(occasion.label)
                    } else {
                        Text("\(pieces.count) capi")
                    }
                }
                .font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
            }
            .padding(10)
        }
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct EmptyOutfits: View {
    let canCompose: Bool
    let compose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 50)).foregroundStyle(Theme.accent)
                .padding(.top, 50)
            Text("Nessun outfit").font(.title3.bold()).foregroundStyle(Theme.text)
            Text(LocalizedStringKey(canCompose
                 ? "Metti insieme i capi dell'armadio: li ritrovi qui, pronti da indossare, e ShadowWear li propone nei giorni giusti."
                 : "Prima aggiungi qualche capo all'armadio, poi componi qui i tuoi outfit."))
                .font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if canCompose {
                Button(action: compose) { Label("Componi un outfit", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 360)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
