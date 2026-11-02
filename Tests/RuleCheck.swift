import AppKit
import WebKit
let app = NSApplication.shared
let json = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "BetterTube-validation", encodedContentRuleList: json) { list, error in
    if let error { print("FAIL: \(error)"); exit(1) }
    guard list != nil else { print("FAIL: empty result"); exit(1) }
    print("PASS: WebKit compiled the ad-blocking rules")
    exit(0)
}
app.run()
