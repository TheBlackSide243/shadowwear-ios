import SwiftUI

/// The numbers of the closet and the diary: what is worn, what is not, the colors, what is liked
/// and the cost per wear.
struct StatsView: View {
    @Environment(Closet.self) private var closet
    @State private var period = Period.all
    /// The year looked back on (nil: the latest with something in the diary) and its picture.
    @State private var year: Int?
    @State private var card: Image?

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
        let months = Care.spending(closet.items)
        let idle = Care.idle(closet.items, wears: closet.wears)
        let years = Care.recapYears(closet.wears)
        let recap = (years.contains(year ?? 0) ? year : years.first).map {
            Care.yearRecap(items: closet.items, outfits: closet.outfits, wears: closet.wears, year: $0)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Periodo", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(value: "\(stats.pieces)", label: "Capi", symbol: "hanger")
                    StatTile(value: "\(stats.daysWritten)", label: "Giorni nel diario", symbol: "calendar")
                    StatTile(value: stats.pieces == 0 ? "—" : "\(Int((Double(stats.wornPieces) / Double(stats.pieces) * 100).rounded()))%", label: "Capi messi", symbol: "checkmark.circle")
                    StatTile(value: "\(stats.neverWorn.count)", label: "Mai messi", symbol: "moon.zzz",
                             color: stats.neverWorn.isEmpty ? Theme.text : Theme.warn)
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
                        Text("Il prezzo diviso per le volte che l'hai messo. Il prezzo si scrive nella scheda del capo.").prose()
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                if months.contains(where: { $0.total > 0 }) { spendingPanel(months) }
                if !idle.isEmpty { idlePanel(idle) }
                if !stats.neverWorn.isEmpty {
                    Panel("Mai messi") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(stats.neverWorn) { item in
                                    NavigationLink(value: AppRoute.item(item.id)) {
                                        PieceImage(item: item)
                                            .frame(width: 72, height: 84)
                                            .background(Theme.stage, in: Theme.roundSmall)
                                            .clipShape(Theme.roundSmall)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(item.displayName))
                                }
                            }
                        }
                    }
                }
                if let recap { recapPanel(recap, years: years) }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Statistiche")
        .navigationBarTitleDisplayMode(.inline)
        // The picture of the year is drawn again when the year, the closet or the look change.
        .task(id: "\(recap?.year ?? 0)-\(closet.items.count)-\(closet.wears.count)-\(Look.shared.palette.id)") {
            card = recap.flatMap { YearCard.render($0, closet: closet) }
        }
    }

    /// What was spent month by month: twelve columns, the amount over each.
    private func spendingPanel(_ months: [Care.MonthSpend]) -> some View {
        let top = max(1, months.map(\.total).max() ?? 1)
        let total = months.map(\.total).reduce(0, +)
        return Panel("Spesa per mese") {
            InfoRow("Negli ultimi 12 mesi", Wish.format(total, currency: ""))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(months) { month in
                    VStack(spacing: 4) {
                        Text(month.total > 0 ? "\(Int(month.total.rounded()))" : " ")
                            .font(.caption2.monospacedDigit()).foregroundStyle(Theme.text)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.input)
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.accent)
                                .frame(height: 96 * month.total / top)
                        }
                        .frame(height: 96)
                        Text(Self.monthName(month.month)).font(.caption2).foregroundStyle(Theme.sub)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(months.filter { $0.total > 0 }
                .map { Self.monthName($0.month, long: true) + ": " + Self.money($0.total) }.joined(separator: ", ")))
            Text("Il prezzo di ogni capo, nel mese in cui è entrato nell'armadio.").prose()
                .font(.caption).foregroundStyle(Theme.sub)
        }
    }

    static func money(_ value: Double) -> String { Wish.format(value, currency: "") }

    /// "nov" for 2026-11, or "novembre 2026" read aloud.
    static func monthName(_ key: String, long: Bool = false) -> String {
        guard let date = Day.date(key + "-01") else { return key }
        return long ? date.formatted(.dateTime.month(.wide).year()) : date.formatted(.dateTime.month(.abbreviated))
    }

    /// Pieces bought, left in the closet for two months and never worn: what they cost, and which.
    private func idlePanel(_ idle: [Item]) -> some View {
        let value = idle.compactMap(\.price).filter { $0 > 0 }.reduce(0, +)
        return Panel("Mai messi dopo 60 giorni") {
            if value > 0 { InfoRow("Soldi fermi nell'armadio", Wish.format(value, currency: ""), color: Theme.warn) }
            ForEach(idle.prefix(6)) { item in
                NavigationLink(value: AppRoute.item(item.id)) {
                    PieceLine(item: item, detail: String(localized: "Nell'armadio dal \(item.created.formatted(date: .abbreviated, time: .omitted))")) {
                        if let price = item.price, price > 0 {
                            Text(Wish.format(price, currency: "")).font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if idle.count > 6 {
                Text("e altri \(idle.count - 6)").font(.caption).foregroundStyle(Theme.sub)
            }
            Text("Nell'armadio da più di due mesi e ancora mai indossati.").prose()
                .font(.caption).foregroundStyle(Theme.sub)
        }
    }

    /// The year as a picture, with the button to share it.
    private func recapPanel(_ recap: Care.YearRecap, years: [Int]) -> some View {
        Panel(YearCard.title(recap.year)) {
            if years.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(years, id: \.self) { entry in
                            Chip(text: String(entry), selected: entry == recap.year) { year = entry }
                        }
                    }
                }
            }
            if let card {
                card.resizable().scaledToFit()
                    .clipShape(Theme.round)
                    .overlay(Theme.round.strokeBorder(Theme.line, lineWidth: 1))
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(YearCard.spoken(recap)))
                ShareLink(item: card, preview: SharePreview(YearCard.title(recap.year), image: card)) {
                    Label("Condividi", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Text("L'anno in un'immagine, da tenere o da mandare a chi vuoi.").prose()
                .font(.caption).foregroundStyle(Theme.sub)
        }
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

/// A year as a picture to share: four numbers, the pieces worn the most, the colors worn and the
/// outfit of the year. The sizes are fixed (no Dynamic Type): the picture is the same for everyone.
struct YearCard: View {
    let recap: Care.YearRecap

    static let size = CGSize(width: 360, height: 450)

    static func title(_ year: Int) -> String { String(localized: "Il tuo \(String(year))") }

    /// The year in a sentence, for who cannot see the picture.
    static func spoken(_ recap: Care.YearRecap) -> String {
        var parts = [String(localized: "\(recap.days) giorni nel diario"), String(localized: "\(recap.wornPieces) capi messi su \(recap.pieces)")]
        if let first = recap.mostWorn.first { parts.append(String(localized: "il più messo: \(first.item.displayName)")) }
        if let top = recap.topOutfit { parts.append(String(localized: "l'outfit dell'anno: \(top.outfit.displayName)")) }
        return parts.joined(separator: ", ")
    }

    /// The picture, three times the size of the view (1080 × 1350).
    @MainActor static func render(_ recap: Care.YearRecap, closet: Closet) -> Image? {
        let renderer = ImageRenderer(content: YearCard(recap: recap).environment(closet))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }

    private static func face(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    private static func times(_ n: Int) -> String {
        n == 1 ? String(localized: "1 volta") : String(localized: "\(n) volte")
    }

    /// Whole units: on a picture the cents only take room.
    private var spent: String {
        recap.spent.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR").precision(.fractionLength(0)))
    }

    /// The last line: the outfit of the year, or the piece that paid for itself best.
    private var closing: (label: String, text: String)? {
        if let top = recap.topOutfit {
            return (String(localized: "L'outfit dell'anno"), top.outfit.displayName + " · " + Self.times(top.times))
        }
        if let best = recap.best {
            let cost = StatsView.money(best.cost)
            return (String(localized: "Il più ripagato"), best.item.displayName + " · " + String(localized: "\(cost) a uso"))
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "SHADOWWEAR").font(Self.face(10)).tracking(2).foregroundStyle(Theme.accent)
            Text(Self.title(recap.year).uppercased())
                .font(Self.face(44)).tracking(-1.5).foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.top, 4)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    tile("\(recap.days)", String(localized: "Giorni nel diario"))
                    tile("\(recap.wornPieces)/\(recap.pieces)", String(localized: "Capi messi"))
                }
                GridRow {
                    tile("\(recap.added)", String(localized: "Capi nuovi"))
                    if recap.spent > 0 {
                        tile(spent, String(localized: "Spesi"))
                    } else {
                        tile(recap.topOutfit.map { "\($0.times)" } ?? "—", String(localized: "Volte l'outfit più messo"))
                    }
                }
            }
            .padding(.top, 14)
            if !recap.mostWorn.isEmpty {
                Text(String(localized: "I più messi").uppercased()).font(Self.face(10)).foregroundStyle(Theme.sub)
                    .padding(.top, 16)
                HStack(alignment: .top, spacing: 8) {
                    ForEach(recap.mostWorn) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            PieceImage(item: entry.item, thumbnail: false)
                                .padding(8)
                                .frame(height: 88)
                                .frame(maxWidth: .infinity)
                                .background(Theme.stage, in: Theme.roundSmall)
                            Text(entry.item.displayName).font(Self.face(9)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(Self.times(entry.times)).font(Self.face(8, .medium)).foregroundStyle(Theme.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Fewer than three: the ones there keep their width.
                    ForEach(0..<max(0, 3 - recap.mostWorn.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity).frame(height: 1)
                    }
                }
                .padding(.top, 8)
            }
            if !recap.colors.isEmpty {
                let total = CGFloat(max(1, recap.colors.map(\.count).reduce(0, +)))
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(recap.colors) { entry in
                            (PaletteColor.named(entry.key)?.color ?? Theme.sub)
                                .frame(width: max(3, g.size.width * CGFloat(entry.count) / total - 2))
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
                .padding(.top, 12)
            }
            Spacer(minLength: 8)
            if let closing {
                VStack(alignment: .leading, spacing: 2) {
                    Text(closing.label.uppercased()).font(Self.face(8, .medium))
                    Text(closing.text).font(Self.face(11)).lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent, in: Capsule())
            }
        }
        .padding(24)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Theme.bg)
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Self.face(23)).tracking(-0.6).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(Self.face(9, .medium)).foregroundStyle(Theme.sub).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: Theme.roundSmall)
    }
}
