import Foundation

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main
struct CoreTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        checks += 1
        guard condition() else { fatalError("FAIL: \(label)") }
    }
    static func main() async throws {
        let id = "abcdefghijk"
        check(YouTubeURL.videoID(from: URL(string:"https://youtu.be/\(id)")!) == id, "short link")
        check(YouTubeURL.videoID(from: URL(string:"https://m.youtube.com/watch?v=\(id)")!) == id, "watch link")
        check(YouTubeURL.videoID(from: URL(string:"https://youtube.com/shorts/\(id)")!) == id, "shorts link")
        check(!YouTubeURL.isYouTube(URL(string:"https://youtube.com.evil.test")!), "host suffix boundary")
        check(!YouTubeURL.isYouTube(URL(string:"http://youtube.com")!), "HTTPS required")
        check(!YouTubeURL.isYouTube(URL(string:"https://youtube.com:444")!), "port boundary")
        check(YouTubeURL.videoID(from: URL(string:"https://youtube.com/watch?v=short")!) == nil, "invalid ID")
        check(URLComponents(url: YouTubeURL.search("cats & dogs #1"), resolvingAgainstBaseURL:false)?.queryItems?.first?.value == "cats & dogs #1", "search encoding")
        check(YouTubeURL.mobile(URL(string:"https://youtu.be/\(id)?t=20")!)?.host == "m.youtube.com", "mobile normalization")
        let request = try SponsorService.request(for:id)
        check(request.url!.path.split(separator:"/").last!.count == 4, "four-character hash")
        check(!request.url!.absoluteString.contains(id), "no raw video ID sent")
        check(request.url!.host == "sponsor.ajay.app", "official API host")
        do { _ = try SponsorService.request(for:"invalid"); fatalError("invalid ID accepted") } catch { checks += 1 }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let service = SponsorService(session: URLSession(configuration: config))
        var requests = 0
        let segment = "{\"segment\":[10,20],\"UUID\":\"one\",\"category\":\"sponsor\",\"actionType\":\"skip\",\"videoDuration\":100}"
        StubProtocol.handler = { _ in
            requests += 1
            return (200, Data("[{\"videoID\":\"unrelated00\",\"segments\":[\(segment)]},{\"videoID\":\"\(id)\",\"segments\":[\(segment)]}]".utf8))
        }
        let found = try await service.segments(for:id)
        check(found.count == 1, "hash bucket selects exact video")
        _ = try await service.segments(for:id)
        check(requests == 1, "cache suppresses duplicate network requests")
        await service.clear()
        StubProtocol.handler = { _ in (404,Data()) }
        let empty = try await service.segments(for:id)
        check(empty.isEmpty, "404 is no segments")
        await service.clear()
        StubProtocol.handler = { _ in (429,Data()) }
        do { _ = try await service.segments(for:id); fatalError("429 accepted") } catch { checks += 1 }
        StubProtocol.handler = { _ in (200,Data("not JSON".utf8)) }
        do { _ = try await service.segments(for:id); fatalError("malformed payload accepted") } catch { checks += 1 }
        StubProtocol.handler = { _ in (200,Data(repeating:32,count:2_000_001)) }
        do { _ = try await service.segments(for:id); fatalError("oversize payload accepted") } catch { checks += 1 }
        StubProtocol.handler = { _ in (200,Data("[{\"videoID\":\"unrelated00\",\"segments\":[\(segment)]}]".utf8)) }
        let collision = try await service.segments(for:id)
        check(collision.isEmpty, "hash collision cannot skip the wrong video")
        let invalid = SponsorSegment(segment:[20,10], UUID:"test", category:"sponsor", actionType:"skip", videoDuration:100)
        check(!invalid.isValid, "reversed timestamps rejected")
        print("PASS: \(checks) Swift core checks")
    }
}
