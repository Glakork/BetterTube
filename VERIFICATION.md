# Verification

## Local checks

- 16 JavaScript regression tests passed: URL validation; timestamp selection; overlapping intervals; Undo; route changes and stale replies; live/mismatched durations; paused/seeking guards; ad-vs-content separation; immediate setting changes.
- 21 Swift core checks passed, including hashed requests, exact bucket matching, caching, HTTP failures, malformed payloads, and timestamp validation.
- Xcode project, Info.plist, and privacy manifest pass property-list validation.
- Native macOS WebKit successfully compiled the ad-block rules.
- GitHub iOS build: validation in progress.

## Required device checks

An iPhone has not been used to validate this version. After signing and installing:

1. Launch, complete onboarding, browse, search, and play a normal YouTube video.
2. Check a video with a submitted SponsorBlock segment. Confirm skip and Undo; repeat with SponsorBlock off.
3. Switch videos rapidly and confirm a previous video’s timestamps never apply.
4. Try pre-roll, mid-roll, banner, and Shorts ads. Confirm normal content is not sought to the end. Record failures; YouTube ad formats can evade these filters.
5. Change accent, switch dark/light/system, quit and reopen, and confirm preferences persist.
6. Test offline reload, interrupted networking, landscape, iPad sizing, and large text/VoiceOver.
7. Confirm external links ask before opening Safari, and clear-website-data leaves settings intact.

No claim of complete ad elimination, Google sign-in, background playback, or universal Picture in Picture support is made.
