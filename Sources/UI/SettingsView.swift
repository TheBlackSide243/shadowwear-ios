import SwiftUI

struct SettingsView: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    @Environment(AIService.self) private var ai
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    @AppStorage(Reminders.enabledKey) private var reminder = false
    @AppStorage(Reminders.hourKey) private var hour = 7
    @AppStorage(Reminders.minuteKey) private var minute = 30
    @State private var denied = false
    @State private var bytes: Int64 = 0
    /// The pages of the first launch, again.
    @State private var introAgain = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Foto") {
                        Toggle(isOn: $removeBackground) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Togli lo sfondo").foregroundStyle(Theme.text)
                                Text("Quando aggiungi un capo, ShadowWear lo ritaglia dallo sfondo. La foto originale resta: puoi rimetterla quando vuoi.")
                                    .font(.caption).foregroundStyle(Theme.sub)
                            }
                        }
                        .tint(Theme.accent)
                    }
                    ServerPanel()
                    Panel("Intelligenza artificiale") {
                        NavigationLink {
                            AISettingsView()
                        } label: {
                            ToolRow(title: "Dove gira l'IA", detail: ai.summary, symbol: "sparkles")
                        }
                        .buttonStyle(.plain)
                    }
                    Panel("Promemoria") {
                        Toggle(isOn: $reminder) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Idea del mattino").foregroundStyle(Theme.text)
                                Text("Una notifica ogni mattina per scegliere cosa mettere, con i capi da lavare.")
                                    .font(.caption).foregroundStyle(Theme.sub)
                            }
                        }
                        .tint(Theme.accent)
                        if reminder {
                            DatePicker("Ora", selection: time, displayedComponents: .hourAndMinute)
                                .foregroundStyle(Theme.text)
                        }
                        if denied {
                            Text("Le notifiche sono spente per ShadowWear: accendile in Impostazioni → Notifiche.")
                                .font(.caption).foregroundStyle(Theme.warn)
                        }
                    }
                    Panel("Archivio") {
                        InfoRow("Capi", "\(closet.items.count)")
                        InfoRow("Foto", "\(closet.photoCount)")
                        InfoRow("Outfit", "\(closet.outfits.count)")
                        InfoRow("Giorni nel diario", "\(Set(closet.wears.map(\.day)).count)")
                        InfoRow("Spazio usato", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        Text("I capi e le foto sono anche nell'app File, nella cartella ShadowWear → Armadio: puoi copiarli per un backup.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    Panel("Info") {
                        InfoRow("Versione", Self.version)
                        Button { introAgain = true } label: {
                            Label("Rivedi l'introduzione", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("© 2026 TheBlackSide243. Tutti i diritti riservati.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fatto") { dismiss() }.bold() }
            }
            .task { bytes = closet.diskUsage() }
            .onChange(of: reminder) { _, on in Task { await reschedule(asking: on) } }
            .onChange(of: hour) { _, _ in Task { await reschedule(asking: false) } }
            .onChange(of: minute) { _, _ in Task { await reschedule(asking: false) } }
            .fullScreenCover(isPresented: $introAgain) {
                WelcomeView(replay: true) { introAgain = false }
            }
        }
    }

    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            hour = parts.hour ?? 7
            minute = parts.minute ?? 30
        })
    }

    private func reschedule(asking: Bool) async {
        if asking, reminder {
            let allowed = await Reminders.allow()
            denied = !allowed
            if !allowed { reminder = false }
        }
        await Reminders.schedule(enabled: reminder, hour: hour, minute: minute, idea: nil, laundry: closet.laundry.count)
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
