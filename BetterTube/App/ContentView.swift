import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.openURL) private var openURL
    @StateObject private var browser = BrowserModel()
    @State private var settingsPresented = false
    @State private var searchPresented = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if preferences.onboardingDone { player }
            else { welcome }
        }
        .task(id: preferences.onboardingDone) {
            if preferences.onboardingDone { await browser.start(preferences) }
        }
        .onChange(of: preferences.fingerprint) { _, _ in browser.update(preferences) }
        .sheet(isPresented: $settingsPresented) { SettingsView(browser: browser) }
        .sheet(isPresented: $searchPresented) { searchSheet }
        .alert("Open in Safari?", isPresented: Binding(get: { browser.externalLink != nil }, set: { if !$0 { browser.externalLink = nil } })) {
            Button("Cancel", role: .cancel) { browser.externalLink = nil }
            Button("Open Safari") {
                if let url = browser.externalLink?.url { openURL(url) }
                browser.externalLink = nil
            }
        } message: { Text(browser.externalLink?.url.host ?? "This link leaves BetterTube.") }
    }

    private var player: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 32)
                Text("BetterTube").font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Button { searchPresented = true } label: { Image(systemName: "magnifyingglass").frame(width: 42, height: 44) }
                    .accessibilityLabel("Search YouTube or open video link")
                Button { settingsPresented = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 42, height: 44) }
                    .accessibilityLabel("Settings")
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16).padding(.vertical, 4)
            ZStack(alignment: .top) {
                YouTubeWebView(browser: browser)
                if browser.loading { ProgressView(value: browser.progress).progressViewStyle(.linear).accessibilityLabel("Loading YouTube") }
                if let error = browser.error {
                    ContentUnavailableView {
                        Label("Let’s try that again", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("Reload", action: browser.reload).buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
                }
            }
            .overlay(alignment: .bottom) {
                if let notice = browser.notice {
                    HStack(spacing: 12) {
                        Image(systemName: "forward.end.fill").foregroundStyle(preferences.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skipped \(notice.title.lowercased())").font(.subheadline.weight(.semibold))
                            Text("\(Int(notice.seconds.rounded())) seconds saved").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button("Undo", action: browser.undoSkip).font(.subheadline.weight(.bold)).padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)))
                    .padding(12)
                    .accessibilityElement(children: .contain)
                }
            }
            Divider()
            HStack {
                navButton("chevron.left", label: "Back", action: browser.goBack).disabled(!browser.canGoBack)
                navButton("chevron.right", label: "Forward", action: browser.goForward).disabled(!browser.canGoForward)
                Spacer(minLength: 0)
                navButton("house", label: "YouTube home") { browser.load(YouTubeURL.home) }
                Spacer(minLength: 0)
                ShareLink(item: browser.pageURL) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }.accessibilityLabel("Share page")
                navButton("arrow.clockwise", label: "Reload", action: browser.reload)
            }
            .foregroundStyle(.primary).padding(.horizontal, 12).padding(.vertical, 2)
        }
        .background(Color(uiColor: .systemBackground))
    }
    private func navButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 44, height: 44) }.accessibilityLabel(label)
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { BrandMark(size: 64); Spacer(); Text("YOUR PLAYER.\nYOUR RULES.").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 12) {
                    Text("A little less noise.\nA lot more video.").font(.system(size: 40, weight: .bold, design: .rounded)).tracking(-1)
                    Text("Welcome to BetterTube, a personal YouTube client built around the way you watch.").foregroundStyle(.secondary).font(.body)
                }
                VStack(alignment: .leading, spacing: 24) {
                    feature("shield.lefthalf.filled", title: "Keep the focus", detail: "Built-in filters hide ad placements and skip detected player ads.")
                    feature("forward.end.fill", title: "Skip the sales pitch", detail: "SponsorBlock skips community-marked sponsors, with Undo when you need it.")
                    feature("paintpalette.fill", title: "Make it yours", detail: "Classic red by default. Pick any accent color and a light or dark appearance.")
                }
                Text("SponsorBlock receives a short hash of the video ID and your IP address. You can turn it off in Settings. Ad filtering depends on YouTube’s player and may not catch every ad.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { preferences.onboardingDone = true } label: {
                    HStack { Text("Start watching"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).padding(12)
                }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 18))
                Text("An independent client. Not affiliated with YouTube or Google.").font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 620)
        }
        .background(Color(uiColor: .systemBackground))
    }
    private func feature(_ icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundStyle(preferences.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
    private var searchSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Search or paste a YouTube link", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    .focused($searchFocused).onSubmit(submitSearch)
                Text("Videos, creators, music, or a link you saved.").font(.subheadline).foregroundStyle(.secondary)
                Button("Search YouTube", action: submitSearch).buttonStyle(.borderedProminent).disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }.padding(24).navigationTitle("Find something good")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { searchPresented = false } } }
                .onAppear { searchFocused = true }
        }.presentationDetents([.medium, .large])
    }
    private func submitSearch() { browser.search(query); searchPresented = false; query = "" }
}
