# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

This is **Starter Plus**, a native iOS radio streaming app built with Swift and UIKit. It streams live radio stations, displays album art/track metadata (via streams and iTunes API), and supports CarPlay.

- **Language**: Swift (63 source files)
- **UI Framework**: UIKit (programmatic, no storyboards)
- **Dependencies**: Managed via Swift Package Manager through the Xcode project (no standalone `Package.swift`). Four SPM packages: FRadioPlayer, LNPopupController, MarqueeLabel, NVActivityIndicatorView
- **CI**: GitHub Actions on `macos-26` runners (see `.github/workflows/ios.yml` and `carplay.yml`)

### Linux Cloud Agent constraints

This is a **macOS/Xcode-only** project. The full build (`xcodebuild`) and iOS Simulator require macOS. On Linux Cloud Agent VMs:

- **Cannot build** the app (`xcodebuild` is macOS-only; UIKit/AVFoundation/CarPlay frameworks are unavailable on Linux)
- **Can lint** with SwiftLint: `swiftlint lint` (static binary installed at `/usr/local/bin/swiftlint`)
- **Can run Swift** for data validation and scripting: `swift -e '...'` or `swift script.swift` (toolchain at `/usr/share/swift/usr/bin`)
- **Can validate JSON** data files (`SwiftRadio/Data/stations.json`, `SwiftRadio/Data/StarterFMSchedule.json`)

### Key commands

| Task | Command | Notes |
|------|---------|-------|
| Lint | `swiftlint lint` | Runs from repo root; reports style violations |
| Swift REPL/script | `swift -e 'print("hello")'` | Requires `/usr/share/swift/usr/bin` in PATH |
| Validate station JSON | `python3 -c "import json; json.load(open('SwiftRadio/Data/stations.json'))"` | Quick JSON syntax check |
| Full build (macOS only) | `xcodebuild build-for-testing -scheme "SwiftRadio" -project "Starter Plus.xcodeproj" -destination "platform=iOS Simulator,name=iPhone 16"` | Requires macOS + Xcode |

### Data files

- `SwiftRadio/Data/stations.json` — 12 radio stations with stream URLs, metadata, and artwork references
- `SwiftRadio/Data/StarterFMSchedule.json` — Weekly broadcast schedule (7 days, ~67 time slots total)
- Station images are in `SwiftRadio/Images.xcassets/Stations/`

### Environment variables

- `PATH` must include `/usr/share/swift/usr/bin` for Swift CLI access (added to `~/.bashrc` by update script)
