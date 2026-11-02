# BetterTube

An independent iPhone and iPad YouTube client with built-in ad filtering, SponsorBlock, and color customization. Requires **iOS 17 or later**. Native SwiftUI controls surround YouTube’s mobile website in a WKWebView. Default accent: **YouTube red (`#FF0000`)**.

## Get the IPA

Open [Actions → Build iOS IPA](https://github.com/Glakork/BetterTube/actions/workflows/build-ios.yml), select a successful run, and download **BetterTube-unsigned-ipa** under Artifacts. Unzip the download to get `BetterTube-unsigned.ipa` and its SHA-256 checksum. Artifact downloads require GitHub sign-in and are retained for 30 days; run the workflow again when needed.

The IPA is compiled for real ARM64 iPhones and iPads. It is **unsigned**, so use a sideloading tool to sign it before installation. No Apple credentials or certificates belong in this repository or its workflow.

### Sideload onto your iPhone

1. Use [Sideloadly](https://sideloadly.io/index.html), or an existing [AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore) / [SideStore](https://docs.sidestore.io/docs/faq) installation.
2. In Sideloadly, connect and trust your iPhone, select `BetterTube-unsigned.ipa`, choose your device, and follow its signing and installation prompts using your own Apple account. For AltStore Classic or SideStore, import the IPA from Files using the app’s install button.
3. Enable Developer Mode or trust the developer profile on the iPhone if iOS requests it, then launch BetterTube.
4. Tap **Start watching**. Open the sliders button to customize filtering and colors.

Free-account signing generally expires after seven days and requires refresh. Follow your sideloading tool’s [current instructions](https://sideloadly.io/faq.html). The app uses one bundle ID and has no extensions. An unsigned IPA cannot be installed by opening it in Safari.

## Features

- YouTube browsing, search, links, Shorts, and the site’s own playback/quality/caption controls.
- WebKit network filters for known advertising domains and endpoints; cosmetic ad-slot hiding; guarded skips on players explicitly marked as showing an ad.
- SponsorBlock auto-skip, a seven-second Undo notice, and eight independently selectable categories. Only sponsors are enabled initially. Undo suppresses the overlapping skipped segments until you leave the video.
- Four-character SHA-256 video lookup, in-memory caching, cancellation on navigation, exact video matching within hash buckets, and rejection of stale duration metadata.
- Six color presets, any custom accent, dark/light/system appearance, and saved preferences. Supported web player controls follow the accent; the Home Screen icon stays red.
- Back/forward, home, refresh, sharing, and clear-website-data controls. iPad and landscape layouts use the same adaptive UI.

## Limits

Ad blocking is best effort. YouTube can change selectors, serve ads from the same endpoints as content, or refuse playback with a blocker. There is no promise of eliminating every ad. Toggle ad blocking off and reload if playback breaks. SponsorBlock needs community submissions and skips only when the video duration matches; live streams with an unknown duration are left alone.

This is a WebKit client, not a modification of Google’s official app. Google sign-in is not supported as an app feature and may be blocked in embedded browsers; a Safari login does not transfer into the app. YouTube or iOS can limit background playback, fullscreen behavior, or Picture in Picture. Downloads, Premium features, native account synchronization, DRM bypass, and system-wide ad blocking are not implemented.

## Privacy and attribution

YouTube receives the pages/videos opened and maintains its own cookies and site data. SponsorBlock sees the client IP and a short hash prefix, not an explicit full video ID in the request URL. Prefix lookup reduces disclosure but is not anonymity. SponsorBlock can be disabled. BetterTube adds no analytics SDK, server, or persistent watch-history database. Clear website data removes WebKit cookies/cache and the in-memory SponsorBlock cache while preserving preferences.

Uses [SponsorBlock](https://sponsor.ajay.app/) data licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). API details: [SponsorBlock API documentation](https://wiki.sponsor.ajay.app/w/API_Docs). The integration is original code; it does not copy the browser extension. YouTube and Google are their respective owners’ trademarks. BetterTube is not affiliated with or endorsed by them. The app icon is original geometric artwork.

## Build locally

Install full Xcode with the iOS SDK, select it in **Xcode → Settings → Locations → Command Line Tools**, then:

```sh
bash scripts/build-ipa.sh
```

Output: `build/BetterTube-unsigned.ipa`. To run directly from Xcode, open `BetterTube.xcodeproj`, select your development team under Signing & Capabilities, choose your iPhone, and Run. No third-party package dependencies are needed.

The checked-in project is ready to open. If source/resource files are added, regenerate its file list with `python3 scripts/generate_project.py`.

## Verification

```sh
node --test Tests/*.test.cjs
mkdir -p build
swiftc -swift-version 5 BetterTube/Core/YouTubeURL.swift BetterTube/Core/SponsorService.swift Tests/CoreTests.swift -o build/core-tests
build/core-tests
```

The workflow runs the JavaScript player regressions and Swift network/URL tests, builds the physical-device app, packages the IPA, compiles the simulator app, and launches it for an onboarding screenshot. These checks do not prove real-world YouTube ad suppression or iPhone playback. See `VERIFICATION.md` for the observed results and remaining device checks.
