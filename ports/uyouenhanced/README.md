# uYouEnhanced Local — both iPads

This restores the working local12 download client from the previously ignored
`.build/uyouenhanced` snapshots into the `ios-ports` Git project. It extends
[uYouEnhanced](https://github.com/arichornlover/uYouEnhanced) at commit
`2b6816069c2156eef626084cf7fe645749a2b152`, with its pinned header/RYD submodules.

| Profile | Device | Minimum OS | Package | Interface |
| --- | --- | --- | --- | --- |
| rootful | iPad Air A1476 / iPad4,3 / A7, Amethyst | iOS 12.0 | `iphoneos-arm` (arm64 binary) | «Сохранённое» launcher, independent library |
| rootless | iPad7,5 / A10, Dopamine | iPadOS 16.0 | `iphoneos-arm64` | Existing uYou «Сохранённое» tab |

The same Objective-C download/library/SponsorBlock sources serve both profiles.
There are two DEBs because rootful and rootless install paths and loader paths
differ. The closed-source upstream uYou 3.0.4 binary requires iOS 13.0; it is
included only in the rootless profile. Its load-command minimum is never falsified.
The rootful profile builds our own library without this binary or its hooks.

## Build

Requires macOS, full Xcode, Python 3.10+, Git, `ldid`, and `dpkg-deb`:

```sh
brew install ldid dpkg
make -C ports/uyouenhanced test
make uyouenhanced
```

One command fetches pinned source and Theos, builds both profiles, signs them,
packages them, and verifies each DEB. Outputs are in `ports/uyouenhanced/dist/`.
Build only one profile with `make -C ports/uyouenhanced rootful` or `rootless`.
The GitHub Actions workflow builds the same pair and uploads artifacts; it does
not silently update dependencies or install anything on a device.

`config.json` records versions, the upstream commit, Theos commit and the SHA-256
of upstream uYou. Temporary checkouts, objects and packages stay outside Git.
The local12 entry-point change is retained as a small upstream patch; shared
sources are in `sources/`, not in a temporary build directory.

## Features

- Russian «Сохранённое» library with high-resolution 16:9 covers, duration,
  full-width search, YouTube-style filters, white menus, sorting, download
  progress and error-only badges, pause/resume, retry, deletion and offline playback.
  The saved tab is placed immediately before the account tab; Shorts and Create
  are removed from the pivot model.
- Menu downloads select the menu's own video ID, never a different playing video.

- The player's download control uses a down-arrow/tray icon and joins YouTube's
  native top controls between captions and settings when both are present. It
  downloads the current video through the same quality menu, independently of
  uYou's old button. The extra rotate/repeat/download row is disabled and detached;
  its actions cannot run, and uYou repeat stays off. Upstream repeat-related patches
  are removed from our compiled sources. The proprietary rootless uYou binary is
  still bundled for its existing tab/integration; its internal bytes are not removed.
- MP4 downloads combine AVC video and AAC audio; HLS uses
  `AVAssetDownloadURLSession`. Signed media URLs are not saved in the library index.
  Before starting, downloads check space for the two tracks plus the merged file;
  preparation checks remaining space again. Expected media lengths are verified
  before merging. Preparation starts in the foreground, prevents automatic screen locking while
  merging, and keeps inputs for retry if iOS suspends the app. Existing generic
  preparation failures are rechecked once; detailed AVFoundation codes are retained.
- Home displays public global music-video/song charts and a public gaming feed
  below the native search row. The native row is located across the outer header as well as the browse view; the
  YouTube title logo is hidden. Public feeds use an ephemeral session without
  account cookies or credentials and do not enable watch history. Pull down to
  refresh. YouTube can change the public page schema or restrict a chart by region.
- SponsorBlock automatically skips **sponsor** segments in YouTube's local player
  and saved videos. Other categories are left alone. The gear button in the library
  turns skipping on/off. SponsorBlock does not control a remote Cast player.
- Segment metadata is cached alongside the library, refreshed after 24 hours when
  possible, and usable offline. No-segments 404 and failed API calls leave playback
  available; failures do not replace a successful cache. Newly downloaded videos
  prefetch metadata. Fetches cannot affect a different video's player.
- Sponsor intervals appear in green on the playback timeline. Markers follow
  the track on resize/fullscreen, stay below the draggable dot and accept no touches.
  Unknown/live durations and ads hide the markers. AVKit's saved-video time slider
  is supported when that system version exposes its AVScrubber UISlider.
- Return YouTube Dislike is compiled from the pinned upstream submodule and
  restores estimated dislike counts in compatible YouTube UIs. Its existing
  settings remain available. The library gear also toggles display. Vote submission
  is off by upstream default; this port does not enable it.

SponsorBlock uses the [official API](https://wiki.sponsor.ajay.app/w/API_Docs).
Dislikes are estimates from [Return YouTube Dislike](https://returnyoutubedislike.com/),
not private official YouTube statistics. Both are community data services.

Public music sources are the official [Top music videos](https://www.youtube.com/playlist?list=PL4fGSI1pDJn5kI81J1fYWK5eZRl1zJ5kM)
and [Top songs](https://www.youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i)
playlists linked from [YouTube Music](https://www.youtube.com/feed/music); gaming
uses the public [Gaming](https://www.youtube.com/gaming) page. The safe JSON parser
supports current lockup view models and legacy renderers without evaluating page
scripts or collecting Shorts/menu/tracking payloads.

## Install and device validation

These are **YouTube tweaks**, not standalone copies of the YouTube app. An existing
compatible `com.google.ios.youtube` installation and an active jailbreak are
required. No YouTube IPA, Apple account or app entitlement is included.

For iOS 12, try downloading the last compatible YouTube version from the App Store
purchase history associated with your Apple account. Availability depends on the
store/account and Google's retained versions. An old app can also be rejected by
YouTube's servers; lowering the tweak's deployment target cannot fix that.

Install the rootful DEB on Amethyst and the rootless DEB on Dopamine using Sileo.
Close YouTube fully and reopen it. After a full device reboot, reactivate the
jailbreak before using the tweak. Existing `UYTOffline` media and its index are not
deleted by installing/upgrading the package. The original local12 DEBs remain in
the old ignored snapshot directory for rollback on the iPadOS 17 device.

Verification covers actual builds, architecture, deployment load commands,
signatures, Substrate paths, injection filters, archive checksums and selection/
skipping/marker-range tests. On 2026-10-11, local13 launched on iPad7,5 with iPadOS
17.7.11 and YouTube 21.40.5, retained eight library entries and played a saved video
with sound (confirmed by the user). On the same device, the user confirmed local14's
download icon between captions/settings, quality menu, green sponsor intervals and
a real automatic skip. A new MP4 download completed with video and audio merged
(device log `videoAndAudio=1`). On-screen dislike rendering was also confirmed by
the user. Local15 was then installed on the same tablet; the user confirmed that
the lower rotate/repeat/download row disappeared and the independent top download
button still opened the quality menu. Runtime confirmed disabled legacy actions,
repeat off, and the saved library mounting with 11 entries. Airplane-mode playback
and the old iOS 12 device remain unverified.
Local16 loaded on the same tablet. Local18 builds and package checks pass for
both profiles. Local19–20 add outline/filled Saved icons for both native pivot views and
Elements tabs, and isolated
thumbnail requests with runtime diagnostics. Local19 runtime confirms 1280 px
thumbnail downloads and the home feed positioned below the search row; the
visual result and icon state still require device confirmation. Preparation recovery
are awaiting device validation. The public parser was also run against actual
YouTube pages (81 available music videos and 5 gaming videos). A reported long
video failure has not yet been reproduced with its exact AVFoundation code.
No compatibility with an untested YouTube version is implied by a passing build.

Sources/credit: arichornlover and qnblackcat (uYouEnhanced/uYouPlus), MiRO92 (uYou),
PoomSmart and the pinned Return-YouTube-Dislikes contributors (RYD), and SponsorBlock
contributors (segment data). Upstream licenses and attribution remain in the
fetched repositories; the proprietary uYou archive is obtained from pinned
upstream only, not copied into this Git repository.
