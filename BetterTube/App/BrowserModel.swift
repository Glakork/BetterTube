import SwiftUI
import WebKit

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    struct SkipNotice: Identifiable { let id: String; let title: String; let seconds: Double }
    struct ExternalLink: Identifiable { let url: URL; var id: String { url.absoluteString } }
    static let world = WKContentWorld.world(name: "BetterTube")
    let webView: WKWebView
    @Published var loading = false
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var pageURL = YouTubeURL.home
    @Published var error: String?
    @Published var filterStatus = "Preparing filters"
    @Published var sponsorStatus = "Open a video to find segments"
    @Published var notice: SkipNotice?
    @Published var adsSkipped = 0
    @Published var externalLink: ExternalLink?
    private var rules: WKContentRuleList?
    private var observations: [NSKeyValueObservation] = []
    private let sponsorService = SponsorService()
    private var segmentTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var currentVideoID: String?
    private var requestGeneration = 0
    private var started = false
    private var preferences: Preferences?
    private let messageProxy = MessageProxy()

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .audio
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        messageProxy.owner = self
        config.userContentController.add(messageProxy, contentWorld: Self.world, name: "betterTube")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            }
        ]
    }

    func start(_ preferences: Preferences) async {
        guard !started else { return }
        started = true
        self.preferences = preferences
        do {
            let json = try resource("AdBlockRules", "json")
            rules = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WKContentRuleList, Error>) in
                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "BetterTube-v1", encodedContentRuleList: json) { list, error in
                    if let list { continuation.resume(returning: list) }
                    else { continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile)) }
                }
            }
            filterStatus = "Network filters ready"
        } catch { filterStatus = "Network filters unavailable; player filtering remains on" }
        update(preferences)
        load(YouTubeURL.home)
    }

    func update(_ preferences: Preferences) {
        self.preferences = preferences
        guard started else { return }
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if preferences.adBlock, let rules { controller.add(rules) }
        do {
            let data = try JSONSerialization.data(withJSONObject: preferences.payload, options: [.sortedKeys])
            let configuration = String(decoding: data, as: UTF8.self)
            let script = "globalThis.BetterTubeConfig = \(configuration);\n" + (try resource("SegmentEngine", "js")) + "\n" + (try resource("PlayerBridge", "js"))
            controller.removeAllUserScripts()
            controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: Self.world))
            webView.callAsyncJavaScript("window.BetterTube?.configure(configuration)", arguments: ["configuration": preferences.payload], in: nil, in: Self.world) { _ in }
            refreshSegments()
        } catch { self.error = "The player components could not be loaded. Reinstall BetterTube." }
    }

    private func resource(_ name: String, _ ext: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw CocoaError(.fileNoSuchFile) }
        return try String(contentsOf: url, encoding: .utf8)
    }
    func load(_ url: URL) {
        guard let url = YouTubeURL.mobile(url) else { return }
        error = nil
        webView.load(URLRequest(url: url))
    }
    func search(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if let url = URL(string: input), let mobile = YouTubeURL.mobile(url) { load(mobile) }
        else { load(YouTubeURL.search(input)) }
    }
    func reload() { error = nil; webView.reload() }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func undoSkip() {
        guard let notice else { return }
        webView.callAsyncJavaScript("return window.BetterTube?.undo(token)", arguments: ["token": notice.id], in: nil, in: Self.world) { _ in }
        self.notice = nil
        noticeTask?.cancel()
    }
    func clearWebsiteData() async {
        segmentTask?.cancel()
        requestGeneration += 1
        currentVideoID = nil
        notice = nil
        webView.stopLoading()
        let store = webView.configuration.websiteDataStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { continuation.resume() }
        }
        await sponsorService.clear()
        load(YouTubeURL.home)
    }

    func received(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              let origin = URL(string: "https://\(message.frameInfo.securityOrigin.host)"), YouTubeURL.isYouTube(origin),
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready", "video":
            if let urlString = body["url"] as? String, let url = URL(string: urlString), YouTubeURL.isYouTube(url) { pageURL = url }
            else if let url = webView.url { pageURL = url }
            let nextID = YouTubeURL.videoID(from: pageURL)
            if nextID != currentVideoID || type == "ready" {
                currentVideoID = nextID
                notice = nil
                refreshSegments()
            }
        case "skipped":
            guard preferences?.sponsorBlock == true, let id = body["videoID"] as? String, id == currentVideoID,
                  let token = body["token"] as? String, token.count < 100,
                  let category = body["category"] as? String, let seconds = body["seconds"] as? Double,
                  seconds.isFinite, seconds > 0, let category = SponsorCategory(rawValue: category) else { return }
            notice = SkipNotice(id: token, title: category.title, seconds: seconds)
            noticeTask?.cancel()
            noticeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                self?.notice = nil
            }
        case "adSkipped": adsSkipped += 1
        default: break
        }
    }

    private func refreshSegments() {
        segmentTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        notice = nil
        guard preferences?.sponsorBlock == true else {
            sponsorStatus = "SponsorBlock is off"
            if let id = currentVideoID { deliver([], for: id) }
            return
        }
        guard let id = currentVideoID else { sponsorStatus = "Open a video to find segments"; return }
        sponsorStatus = "Finding segments…"
        segmentTask = Task { [weak self, sponsorService] in
            do {
                let segments = try await sponsorService.segments(for: id)
                guard !Task.isCancelled, let self, self.currentVideoID == id, self.requestGeneration == generation else { return }
                let count = segments.filter { self.preferences?.categories.contains($0.category) == true }.count
                self.sponsorStatus = count == 0 ? "No selected segments for this video" : "\(count) segment\(count == 1 ? "" : "s") ready to skip"
                self.deliver(segments, for: id)
            } catch {
                guard !Task.isCancelled, let self, self.currentVideoID == id, self.requestGeneration == generation else { return }
                self.sponsorStatus = "SponsorBlock unavailable · playback still works"
                self.deliver([], for: id)
            }
        }
    }
    private func deliver(_ segments: [SponsorSegment], for id: String) {
        guard let data = try? JSONEncoder().encode(segments), let array = try? JSONSerialization.jsonObject(with: data) else { return }
        webView.callAsyncJavaScript("return window.BetterTube?.setSegments(videoID, segments)", arguments: ["videoID": id, "segments": array], in: nil, in: Self.world) { _ in }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true; error = nil; notice = nil
        segmentTask?.cancel(); requestGeneration += 1; currentVideoID = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        if let url = webView.url { pageURL = url }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        loading = false
        self.error = "YouTube couldn’t load. Check your connection and try again."
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loading = false; error = "The player stopped. Reload to continue."
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        // Embedded media frames may load HTTPS resources; privileged bridge is main-frame-only.
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(url.scheme == "https" || url.scheme == "about" ? .allow : .cancel); return
        }
        if YouTubeURL.isYouTube(url) { decisionHandler(.allow); return }
        if url.scheme == "about" { decisionHandler(.allow); return }
        if url.scheme == "https" || url.scheme == "http" { externalLink = ExternalLink(url: url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if YouTubeURL.isYouTube(url) { load(url) }
            else if url.scheme == "https" || url.scheme == "http" { externalLink = ExternalLink(url: url) }
        }
        return nil
    }
}

@MainActor
private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: BrowserModel?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { owner?.received(message) }
}

struct YouTubeWebView: UIViewRepresentable {
    let browser: BrowserModel
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
