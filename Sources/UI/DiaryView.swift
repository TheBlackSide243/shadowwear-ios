import SwiftUI

/// What was worn, month by month: a calendar with a photo on the days written down, the day
/// tapped below it, and a few numbers on the month.
struct DiaryView: View {
    @Environment(Closet.self) private var closet
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selected = Day.key(Date())
    @State private var logging: OutfitDraft?
    @State private var pickingOutfit = false
    @State private var path: [AppRoute] = []

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    MonthGrid(month: month, selected: $selected)
                    dayPanel
                    stats
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Diario")
            .navigationBarTitleDisplayMode(.inline)
            .appDestinations()
        }
        .sheet(item: $logging) { draft in
            OutfitEditor(draft: draft) { _ in logging = nil }
        }
        .sheet(isPresented: $pickingOutfit) {
            OutfitPicker { outfit in
                pickingOutfit = false
                if let outfit, let date = Day.date(selected) { closet.wear(outfit, on: date) }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                .accessibilityLabel(Text("Mese prima"))
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                .font(.title3.bold()).foregroundStyle(Theme.text)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                .accessibilityLabel(Text("Mese dopo"))
        }
    }

    private func move(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) { month = next }
    }

    @ViewBuilder private var dayPanel: some View {
        let entries = closet.wears(on: selected)
        let date = Day.date(selected) ?? Date()
        let future = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
        Panel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized) {
            if entries.isEmpty {
                Text(LocalizedStringKey(future ? "Questo giorno deve ancora arrivare." : "Niente annotato per questo giorno."))
                    .font(.subheadline).foregroundStyle(Theme.sub)
            }
            ForEach(entries) { entry in
                let pieces = entry.items.compactMap(closet.item)
                HStack(spacing: 12) {
                    OutfitCollage(items: pieces, spacing: 3)
                        .frame(width: 70, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        if let outfit = entry.outfit.flatMap(closet.outfit) {
                            NavigationLink(value: AppRoute.outfit(outfit.id)) {
                                Text(outfit.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Capi scelti").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        }
                        Text(pieces.isEmpty ? String(localized: "Capi non più nell'armadio") : pieces.map(\.displayName).joined(separator: ", "))
                            .font(.caption).foregroundStyle(Theme.sub).lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive) { closet.removeWear(entry.id) } label: { Image(systemName: "trash") }
                        .foregroundStyle(Theme.sub)
                        .accessibilityLabel(Text("Togli dal diario"))
                }
            }
            if !future, !closet.items.isEmpty {
                HStack(spacing: 10) {
                    if !closet.outfits.isEmpty {
                        Button { pickingOutfit = true } label: { Label("Un outfit", systemImage: "square.stack.3d.up").frame(maxWidth: .infinity) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button {
                        logging = OutfitDraft(logDate: date)
                    } label: { Label("Dei capi", systemImage: "tshirt").frame(maxWidth: .infinity) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    @ViewBuilder private var stats: some View {
        let monthKey = String(Day.key(month).prefix(7))
        let entries = closet.wears.filter { $0.day.hasPrefix(monthKey) }
        let days = Set(entries.map(\.day)).count
        let counts = Dictionary(entries.flatMap { Array(Set($0.items)) }.map { ($0, 1) }, uniquingKeysWith: +)
        let top = counts.sorted { $0.value > $1.value }.prefix(3).compactMap { pair in closet.item(pair.key).map { ($0, pair.value) } }
        let everWorn = Set(closet.wears.flatMap(\.items))
        let never = closet.items.filter { !everWorn.contains($0.id) }
        Panel("Il mese") {
            InfoRow("Giorni annotati", "\(days)")
            if !top.isEmpty {
                Text("I più messi").font(.caption.weight(.semibold)).foregroundStyle(Theme.sub)
                ForEach(top, id: \.0.id) { pair in
                    NavigationLink(value: AppRoute.item(pair.0.id)) {
                        HStack {
                            PieceRow(item: pair.0)
                            Text("\(pair.1)×").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            InfoRow("Capi mai messi", String(localized: "\(never.count) di \(closet.items.count)"))
            if !never.isEmpty, closet.wears.count >= 5 {
                Text("Tra i capi mai messi: \(never.prefix(3).map(\.displayName).joined(separator: ", ")).")
                    .font(.caption).foregroundStyle(Theme.sub)
            }
        }
    }
}

/// The month as a grid, Monday (or the phone's first weekday) first.
struct MonthGrid: View {
    @Environment(Closet.self) private var closet
    let month: Date
    @Binding var selected: String

    private let calendar = Calendar.current

    private var cells: [String?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        let days: [String?] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: month).map { Day.key($0) }
        }
        return Array(repeating: nil, count: lead) + days
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        let today = Day.key(Date())
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { pair in
                    Text(pair.element).font(.caption2.bold()).foregroundStyle(Theme.sub)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { pair in
                    if let key = pair.element {
                        DayCell(key: key, isToday: key == today, isSelected: key == selected,
                                piece: closet.wears(on: key).first?.items.compactMap(closet.item).first) {
                            selected = key
                        }
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let key: String
    let isToday: Bool
    let isSelected: Bool
    let piece: Item?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(piece != nil ? Theme.photo : Theme.panel)
                if let piece {
                    PieceImage(item: piece).padding(EdgeInsets(top: 14, leading: 4, bottom: 3, trailing: 4))
                }
                Text(String(Int(key.suffix(2)) ?? 0))
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Theme.accent : Theme.text)
                    .padding(4)
            }
            .frame(height: 52)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? Theme.accent : (isToday ? Theme.accent.opacity(0.4) : Theme.line), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Day.date(key)?.formatted(date: .complete, time: .omitted) ?? key))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Picks one of the saved outfits.
struct OutfitPicker: View {
    @Environment(Closet.self) private var closet
    let picked: (Outfit?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)], spacing: 12) {
                    ForEach(closet.outfits.sorted { $0.created > $1.created }) { outfit in
                        Button { picked(outfit) } label: { OutfitCard(outfit: outfit) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Scegli l'outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { picked(nil) } }
            }
        }
    }
}
