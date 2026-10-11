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

- Russian «Сохранённое» library with covers, search, filters, sorting, visible
  progress/errors, pause/resume, retry, deletion and offline AVPlayer playback.
- Menu downloads select the menu's own video ID, never a different playing video.
  The «Скачать» button also accepts a YouTube link or an exact video ID.
- The player's download control uses a down-arrow/tray icon and joins YouTube's
  native top controls between captions and settings when both are present. It
  downloads the current video through the same quality menu; uYou's speed controls
  keep their actions and receive Russian accessibility labels.
- MP4 downloads combine AVC video and AAC audio; HLS uses
  `AVAssetDownloadURLSession`. Signed media URLs are not saved in the library index.
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
the user. Airplane-mode playback and the old iOS 12 device remain unverified.
No compatibility with an untested YouTube version is implied by a passing build.

Sources/credit: arichornlover and qnblackcat (uYouEnhanced/uYouPlus), MiRO92 (uYou),
PoomSmart and the pinned Return-YouTube-Dislikes contributors (RYD), and SponsorBlock
contributors (segment data). Upstream licenses and attribution remain in the
fetched repositories; the proprietary uYou archive is obtained from pinned
upstream only, not copied into this Git repository.
