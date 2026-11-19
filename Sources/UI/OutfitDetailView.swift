import SwiftUI

/// One outfit: the collage, its pieces, when it was worn, and "I wore it today".
struct OutfitDetailView: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    let id: Outfit.ID

    @State private var editing: OutfitDraft?
    @State private var confirmDelete = false
    /// The outfit drawn as a picture, to share.
    @State private var card: Image?

    var body: some View {
        Group {
            if let outfit = closet.outfit(id) {
                content(outfit)
            } else {
                Text("Questo outfit non c'è più.").foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screen()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { draft in
            OutfitEditor(draft: draft) { _ in editing = nil }
        }
        .confirmationDialog("Eliminare questo outfit?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina l'outfit (i capi restano)", role: .destructive) {
                closet.deleteOutfit(id)
                dismiss()
            }
        }
    }

    private func content(_ outfit: Outfit) -> some View {
        let pieces = closet.pieces(of: outfit)
        let days = closet.days(wornOutfit: outfit.id)
        let today = Day.key(Date())
        let todayWear = closet.wears(on: today).first { $0.outfit == outfit.id }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OutfitCollage(items: pieces, spacing: 10, thumbnail: false)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 6) {
                    Text(outfit.displayName).font(.title2.bold()).foregroundStyle(Theme.text)
                    if let occasion = outfit.occasion {
                        Label(occasion.label, systemImage: occasion.symbol).font(.subheadline).foregroundStyle(Theme.sub)
                    }
                }
                if let todayWear {
                    HStack {
                        Label("Messo oggi", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good)
                        Spacer()
                        Button("Annulla") { closet.removeWear(todayWear.id) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    Button { closet.wear(outfit) } label: { Label("L'ho messo oggi", systemImage: "checkmark.circle") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(pieces.isEmpty)
                }
                Panel("Capi") {
                    if pieces.isEmpty {
                        Text("I capi di questo outfit non sono più nell'armadio.").font(.subheadline).foregroundStyle(Theme.sub)
                    }
                    ForEach(pieces) { piece in
                        NavigationLink(value: AppRoute.item(piece.id)) { PieceRow(item: piece) }
                            .buttonStyle(.plain)
                    }
                }
                Panel("Diario") {
                    InfoRow("Messo", days.count == 1 ? String(localized: "1 volta") : String(localized: "\(days.count) volte"))
                    InfoRow("L'ultima volta", days.first.flatMap { Day.date($0) }.map { $0.formatted(date: .long, time: .omitted) } ?? "—")
                    InfoRow("Creato il", outfit.created.formatted(date: .long, time: .omitted))
                }
                if !outfit.notes.isEmpty {
                    Panel("Note") {
                        Text(outfit.notes).font(.subheadline).foregroundStyle(Theme.text).textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
        .task(id: outfit.updated) { card = render(outfit, pieces) }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let card {
                    ShareLink(item: card, preview: SharePreview(outfit.displayName, image: card)) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    closet.toggleFavoriteOutfit(outfit.id)
                } label: {
                    Label(LocalizedStringKey(outfit.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti"),
                          systemImage: outfit.favorite ? "star.fill" : "star")
                }
                Menu {
                    Button { editing = OutfitDraft(outfit: outfit, isNew: false) } label: { Label("Modifica", systemImage: "pencil") }
                    Button {
                        var copy = Outfit(name: String(localized: "\(outfit.displayName) (copia)"), items: outfit.items, occasion: outfit.occasion)
                        copy.notes = outfit.notes
                        closet.add(copy)
                    } label: { Label("Duplica", systemImage: "plus.square.on.square") }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina", systemImage: "trash") }
                } label: { Label("Azioni", systemImage: "ellipsis.circle") }
            }
        }
    }
}

extension OutfitDetailView {
    /// The collage with the name and the pieces under it, on the dark background, as a picture.
    @MainActor func render(_ outfit: Outfit, _ pieces: [Item]) -> Image? {
        guard !pieces.isEmpty else { return nil }
        let view = VStack(alignment: .leading, spacing: 14) {
            OutfitCollage(items: pieces, spacing: 10)
                .frame(height: 560)
                .background(Theme.photo, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(outfit.displayName).font(.title.bold()).foregroundStyle(Theme.text)
            Text(pieces.map(\.displayName).joined(separator: " · ")).font(.body).foregroundStyle(Theme.sub)
            Text("ShadowWear").font(.caption.bold()).foregroundStyle(Theme.accent)
        }
        .padding(28)
        .frame(width: 600)
        .background(Theme.bg)
        .environment(closet)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// A piece in a list: small photo, name, kind.
struct PieceRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            PieceImage(item: item)
                .padding(5)
                .frame(width: 54, height: 60)
                .background(Theme.photo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                HStack(spacing: 5) {
                    if let key = item.colors.first, let swatch = PaletteColor.named(key) { ColorDot(color: swatch.color, size: 9) }
                    Text(item.brand.isEmpty ? item.category.label : item.brand).font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.sub)
        }
        .contentShape(Rectangle())
    }
}
