import Foundation

enum YouTubeURL {
    static let home = URL(string: "https://m.youtube.com")!
    static func isYouTube(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased(), url.port == nil || url.port == 443 else { return false }
        return host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be"
    }
    static func videoID(from url: URL) -> String? {
        guard isYouTube(url) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let candidate: String?
        if url.host == "youtu.be" { candidate = parts.first }
        else if ["shorts", "embed", "live"].contains(parts.first ?? "") { candidate = parts.dropFirst().first }
        else if url.path == "/watch" { candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value }
        else { candidate = nil }
        return candidate.flatMap { isVideoID($0) ? $0 : nil }
    }
    static func isVideoID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }
    static func search(_ query: String) -> URL {
        var parts = URLComponents(string: "https://m.youtube.com/results")!
        parts.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return parts.url!
    }
    static func mobile(_ url: URL) -> URL? {
        guard isYouTube(url) else { return nil }
        if let id = videoID(from: url), url.host == "youtu.be" {
            var parts = URLComponents(string: "https://m.youtube.com/watch")!
            parts.queryItems = [URLQueryItem(name: "v", value: id)] + (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).filter { ["t", "start", "list"].contains($0.name) }
            return parts.url
        }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if ["www.youtube.com", "youtube.com"].contains(url.host ?? "") { parts.host = "m.youtube.com" }
        return parts.url
    }
}
