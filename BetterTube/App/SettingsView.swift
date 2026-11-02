import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var browser: BrowserModel
    @State private var clearConfirmation = false
    @State private var clearing = false
    private let presets: [(String, String)] = [("YouTube Red", "FF0000"), ("Coral", "FF6B5E"), ("Amber", "F5A623"), ("Mint", "24BFA5"), ("Blue", "3578F6"), ("Violet", "9B6DFF")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        BrandMark(size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BetterTube").font(.title2.weight(.bold))
                            Text("A quieter way to watch.").foregroundStyle(.secondary).font(.subheadline)
                        }
                    }.padding(.vertical, 10)
                }
                Section {
                    Toggle(isOn: $preferences.adBlock) { Label("Ad blocking", systemImage: "shield.lefthalf.filled") }
                    Text(preferences.adBlock ? browser.filterStatus : "Ad blocking is off").font(.caption).foregroundStyle(.secondary)
                    if browser.adsSkipped > 0 { Text("\(browser.adsSkipped) player ad skip\(browser.adsSkipped == 1 ? "" : "s") this session").font(.caption).foregroundStyle(.secondary) }
                } header: { Text("Less interruption") } footer: {
                    Text("Filters ad requests and placements, then skips detected player ads. YouTube changes can affect results. Reload a video if an ad has already buffered.")
                }
                Section {
                    Toggle(isOn: $preferences.sponsorBlock) { Label("SponsorBlock", systemImage: "forward.end.fill") }
                    Text(browser.sponsorStatus).font(.caption).foregroundStyle(.secondary)
                    if preferences.sponsorBlock {
                        ForEach(SponsorCategory.allCases) { category in
                            Toggle(category.title, isOn: Binding(get: { preferences.categories.contains(category.rawValue) }, set: { on in
                                if on { preferences.categories.insert(category.rawValue) } else { preferences.categories.remove(category.rawValue) }
                            }))
                        }
                    }
                } header: { Text("Skip what you choose") } footer: {
                    Text("Sponsors are selected by default. Every skip has an Undo button. Segments come from the SponsorBlock community and may not exist for every video.")
                }
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 18) {
                        ForEach(presets, id: \.1) { name, hex in
                            Button { preferences.accentHex = hex } label: {
                                VStack(spacing: 7) {
                                    Circle().fill(Color(hex: hex)).frame(width: 42, height: 42)
                                        .overlay { if preferences.accentHex == hex { Image(systemName: "checkmark").font(.headline.weight(.bold)).foregroundStyle(.white).shadow(radius: 2) } }
                                    Text(name == "YouTube Red" ? "Red" : name).font(.caption).foregroundStyle(.primary)
                                }.frame(minWidth: 60, minHeight: 68)
                            }.buttonStyle(.plain).accessibilityLabel(name).accessibilityAddTraits(preferences.accentHex == hex ? .isSelected : [])
                        }
                    }.padding(.vertical, 10)
                    ColorPicker("Custom accent", selection: Binding(get: { preferences.accent }, set: { preferences.setColor($0) }), supportsOpacity: false)
                    Picker("Appearance", selection: $preferences.appearance) {
                        Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system")
                    }
                    Button("Reset to YouTube Red") { preferences.accentHex = "FF0000" }
                } header: { Text("Make it yours") } footer: { Text("Your accent follows you across the app and supported YouTube player controls. The Home Screen icon stays red.") }
                Section {
                    Button(role: .destructive) { clearConfirmation = true } label: { Text(clearing ? "Clearing…" : "Clear website data") }.disabled(clearing)
                    Link("SponsorBlock & community", destination: URL(string: "https://sponsor.ajay.app")!)
                    Link("SponsorBlock data license", destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                    Link("Source code & updates", destination: URL(string: "https://github.com/Glakork/BetterTube")!)
                    Text("BetterTube 1.0 · iOS 17+").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Your data & this app") } footer: {
                    Text("YouTube receives the pages and videos you open and stores its own website data. SponsorBlock receives a four-character SHA-256 prefix of the video ID and your IP address. No BetterTube analytics, accounts, or watch-history database. Uses SponsorBlock data under CC BY-NC-SA 4.0. Google sign-in may be restricted in embedded browsers; signing in through Safari does not sign in here. BetterTube is independent of YouTube and Google.")
                }
            }
            .navigationTitle("Your BetterTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Clear YouTube cookies, cache, and website data?", isPresented: $clearConfirmation, titleVisibility: .visible) {
                Button("Clear website data", role: .destructive) {
                    clearing = true
                    Task { await browser.clearWebsiteData(); clearing = false }
                }
            } message: { Text("This signs you out of the embedded website. Your theme and skip preferences stay saved.") }
        }
    }
}
