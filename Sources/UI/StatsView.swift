import SwiftUI

/// The numbers of the closet and the diary: what is worn, what is not, the colors, what is liked
/// and the cost per wear.
struct StatsView: View {
    @Environment(Closet.self) private var closet
    @State private var period = Period.all

    enum Period: String, CaseIterable, Identifiable {
        case month, year, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .month: String(localized: "30 giorni")
            case .year: String(localized: "Un anno")
            case .all: String(localized: "Sempre")
            }
        }
        var since: String? {
            switch self {
            case .month: Day.key(Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
            case .year: Day.key(Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date())
            case .all: nil
            }
        }
    }

    var body: some View {
        let stats = Care.stats(items: closet.items, outfits: closet.outfits, wears: closet.wears, since: period.since)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Periodo", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    Tile(value: "\(stats.pieces)", label: "Capi")
                    Tile(value: "\(stats.daysWritten)", label: "Giorni nel diario")
                    Tile(value: stats.pieces == 0 ? "—" : "\(Int((Double(stats.wornPieces) / Double(stats.pieces) * 100).rounded()))%", label: "Capi messi")
                    Tile(value: "\(stats.neverWorn.count)", label: "Mai messi")
                }

                if stats.byCategory.isEmpty {
                    Empty(symbol: "chart.bar", title: "Ancora nessun dato", text: "Segna nel diario cosa indossi: qui vedrai cosa metti di più, i colori e quanto ti costa ogni uso.")
                } else {
                    Panel("Cosa metti, per tipo") {
                        let top = max(1, stats.byCategory.map(\.count).max() ?? 1)
                        ForEach(stats.byCategory) { entry in
                            let category = Category(rawValue: entry.key)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label(category?.label ?? entry.key, systemImage: category?.symbol ?? "square")
                                        .font(.caption).foregroundStyle(Theme.text)
                                    Spacer()
                                    Text("\(entry.count)").font(.caption.monospacedDigit()).foregroundStyle(Theme.sub)
                                }
                                Bar(value: Double(entry.count) / Double(top))
                            }
                        }
                    }
                    Panel("I colori che metti") { colorBar(stats.byColor) }
                }
                if !stats.closetColors.isEmpty {
                    Panel("I colori dell'armadio") { colorBar(stats.closetColors) }
                }
                if !stats.mostWorn.isEmpty {
                    Panel("I più messi") {
                        ForEach(stats.mostWorn, id: \.item.id) { entry in
                            NavigationLink(value: AppRoute.item(entry.item.id)) {
                                PieceLine(item: entry.item, detail: entry.times == 1 ? String(localized: "1 volta") : String(localized: "\(entry.times) volte")) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !stats.liked.isEmpty {
                    Panel("Ti piacciono di più") {
                        ForEach(stats.liked) { item in
                            NavigationLink(value: AppRoute.item(item.id)) {
                                PieceLine(item: item, detail: String(localized: "Dai giorni con il pollice in su")) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !stats.costPerWear.isEmpty {
                    Panel("Costo per uso") {
                        InfoRow("Valore dell'armadio", Wish.format(stats.closetValue, currency: ""))
                        ForEach(stats.costPerWear.prefix(8)) { entry in
                            NavigationLink(value: AppRoute.item(entry.item.id)) {
                                PieceLine(item: entry.item,
                                          detail: entry.times == 0 ? String(localized: "Mai messo") : String(localized: "Messo \(entry.times) volte")) {
                                    Text(Wish.format(entry.cost, currency: "")).font(.subheadline.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(entry.times == 0 ? Theme.warn : Theme.text)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Il prezzo diviso per le volte che l'hai messo. Il prezzo si scrive nella scheda del capo.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                if !stats.neverWorn.isEmpty {
                    Panel("Mai messi") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(stats.neverWorn) { item in
                                    NavigationLink(value: AppRoute.item(item.id)) {
                                        PieceImage(item: item)
                                            .frame(width: 72, height: 84)
                                            .background(Theme.photo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(item.displayName))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Statistiche")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The colors as one bar in their own colors, and the names below.
    private func colorBar(_ counts: [Care.Stats.Count]) -> some View {
        let total = max(1, counts.map(\.count).reduce(0, +))
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(counts) { entry in
                        (PaletteColor.named(entry.key)?.color ?? Theme.sub)
                            .frame(width: max(3, g.size.width * CGFloat(entry.count) / CGFloat(total) - 2))
                    }
                }
            }
            .frame(height: 22)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            FlowLayout(spacing: 10) {
                ForEach(counts.prefix(8)) { entry in
                    HStack(spacing: 5) {
                        ColorDot(color: PaletteColor.named(entry.key)?.color ?? Theme.sub, size: 10)
                        Text("\(PaletteColor.named(entry.key)?.name ?? entry.key) \(Int((Double(entry.count) / Double(total) * 100).rounded()))%")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
            }
        }
    }
}

private struct Tile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(Theme.text)
            Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
