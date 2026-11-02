import Foundation
import CryptoKit

enum SponsorCategory: String, CaseIterable, Codable, Identifiable {
    case sponsor, selfpromo, interaction, intro, outro, preview, music_offtopic, filler
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sponsor: return "Sponsors"
        case .selfpromo: return "Self promotion"
        case .interaction: return "Like & subscribe reminders"
        case .intro: return "Intros"
        case .outro: return "Outros"
        case .preview: return "Previews & recaps"
        case .music_offtopic: return "Non-music sections"
        case .filler: return "Off-topic tangents"
        }
    }
}

struct SponsorSegment: Codable, Sendable {
    let segment: [Double]
    let UUID: String
    let category: String
    let actionType: String
    let videoDuration: Double
    var isValid: Bool {
        segment.count == 2 && segment.allSatisfy(\.isFinite) && segment[0] >= 0 && segment[1] > segment[0] &&
        actionType == "skip" && SponsorCategory(rawValue: category) != nil && !UUID.isEmpty && videoDuration.isFinite && videoDuration >= 0
    }
}

actor SponsorService {
    struct Bucket: Decodable { let videoID: String; let segments: [SponsorSegment] }
    struct CacheEntry { let segments: [SponsorSegment]; let expires: Date }
    enum ServiceError: LocalizedError {
        case invalidVideo, badResponse, http(Int), oversized
        var errorDescription: String? {
            switch self {
            case .invalidVideo: return "Invalid video link."
            case .badResponse: return "SponsorBlock returned an unreadable response."
            case .http(let code): return "SponsorBlock is unavailable (\(code))."
            case .oversized: return "SponsorBlock returned too much data."
            }
        }
    }
    private let session: URLSession
    private var cache: [String: CacheEntry] = [:]
    init(session: URLSession = .shared) { self.session = session }

    static func request(for videoID: String) throws -> URLRequest {
        guard YouTubeURL.isVideoID(videoID) else { throw ServiceError.invalidVideo }
        let hash = SHA256.hash(data: Data(videoID.utf8)).map { String(format: "%02x", $0) }.joined()
        var components = URLComponents(string: "https://sponsor.ajay.app/api/skipSegments/\(hash.prefix(4))")!
        let categories = String(data: try JSONEncoder().encode(SponsorCategory.allCases.map(\.rawValue)), encoding: .utf8)!
        components.queryItems = [URLQueryItem(name: "categories", value: categories), URLQueryItem(name: "actionType", value: "skip")]
        var request = URLRequest(url: components.url!, timeoutInterval: 12)
        request.setValue("BetterTube/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    func segments(for videoID: String) async throws -> [SponsorSegment] {
        if let entry = cache[videoID], entry.expires > Date() { return entry.segments }
        let (data, response) = try await session.data(for: Self.request(for: videoID))
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ServiceError.badResponse }
        let segments: [SponsorSegment]
        if response.statusCode == 404 { segments = [] }
        else {
            guard response.statusCode == 200 else { throw ServiceError.http(response.statusCode) }
            guard data.count <= 2_000_000 else { throw ServiceError.oversized }
            let buckets = try JSONDecoder().decode([Bucket].self, from: data)
            segments = (buckets.first { $0.videoID == videoID }?.segments ?? []).filter(\.isValid)
        }
        if cache.count >= 100 { cache.removeAll(keepingCapacity: true) }
        cache[videoID] = CacheEntry(segments: segments, expires: Date().addingTimeInterval(segments.isEmpty ? 300 : 1800))
        return segments
    }
    func clear() { cache.removeAll() }
}
