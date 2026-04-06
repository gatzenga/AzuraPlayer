import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    var body: some View {
        NavigationStack {
            List {
                Section("Erscheinungsbild") {
                    Toggle("Dark Mode aktivieren", isOn: $isDarkModeEnabled)
                    Text("Wenn aktiviert, wird die App immer im Dunklen Modus angezeigt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Rechtliches") {
                    NavigationLink("Datenschutz") {
                        LegalTextView(title: "Datenschutz", content: datenschutzText)
                    }
                    NavigationLink("Impressum") {
                        LegalTextView(title: "Impressum", content: impressumText)
                    }
                    NavigationLink("Nutzungsbedingungen") {
                        LegalTextView(title: "Nutzungsbedingungen", content: nutzungsbedingungenText)
                    }
                }

                Section("Open Source") {
                    Link(destination: URL(string: "https://github.com/GatzeStreicheln/AzuraPlayer")!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.secondary)
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Info") {
                    Text("AzuraPlayer v0.1")
                }

                Color.clear
                    .frame(height: 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Einstellungen")
        }
    }
}

// MARK: - Wiederverwendbare Text-View

struct LegalTextView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.body)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Texte

private let datenschutzText = """
Kurz gesagt: Ich sammle keine persönlichen Daten von dir. Kein Tracking, keine Werbung, kein Konto.

Was die App macht
AzuraPlayer speichert lokal auf deinem Gerät die Stationen, die du hinzufügst. Diese Daten verlassen dein Gerät nicht und werden nicht an mich übermittelt.

Wenn du einen Radiostream abrufst, verbindet sich die App direkt mit dem Azuracast-Server der jeweiligen Station. Dabei können dort technische Daten wie deine IP-Adresse anfallen – das liegt aber ausserhalb meiner Kontrolle und ist Sache des Stationsbetreibers.

App Store
Wenn du die App über den Apple App Store lädst, gelten zusätzlich die Datenschutzregeln von Apple. Darauf habe ich keinen Einfluss.

Fragen?
Schreib mir einfach: kontakt@azuraplayer.ch

Stand: April 2026 · AzuraPlayer · Schweiz
"""

private let impressumText = """
AzuraPlayer ist ein privates Hobbyprojekt einer Einzelperson aus der Schweiz.

Ich entwickle diese App in meiner Freizeit – ohne kommerzielle Absichten.

Kontakt
Bei Fragen oder Anliegen erreichst du mich per E-Mail:
kontakt@azuraplayer.ch

Hinweis zu Inhalten
AzuraPlayer zeigt Radiostationen an, die von Nutzern selbst hinzugefügt werden. Für deren Inhalte bin ich nicht verantwortlich – das liegt bei den jeweiligen Stationsbetreibern.

Stand: April 2026 · AzuraPlayer · Schweiz
"""

private let nutzungsbedingungenText = """
AzuraPlayer ist ein kleines Open-Source-Hobbyprojekt (MIT-Lizenz), das ich in meiner Freizeit entwickle. Der Quellcode ist öffentlich auf GitHub verfügbar.

Was die App ist
AzuraPlayer ist eine Wiedergabe-App für Azuracast-Radiostationen. Du kannst deine eigenen Stationen hinzufügen und deren Livestreams abspielen. Ich betreibe selbst keine Stationen und bin kein Radiosender.

Was ich erwarte
Bitte nutz die App nur für legale Zwecke – also keine Stationen hinzufügen, deren Inhalte gegen Gesetze verstossen.

Preis
Die App kostet einmalig CHF 1.00 im App Store – oder ist kostenlos, je nach aktueller Version. Das ist kein grosses Geschäft, sondern eine kleine Anerkennung für den Aufwand. Wer den Code selbst kompilieren möchte, kann das dank MIT-Lizenz jederzeit kostenlos tun.

Haftung
Ich mache das nach bestem Gewissen, aber ich kann keine Verfügbarkeit garantieren und bin nicht verantwortlich für Inhalte der Stationen, die Nutzer hinzufügen.

Kontakt
kontakt@azuraplayer.ch

Stand: April 2026 · AzuraPlayer · Schweiz
"""
