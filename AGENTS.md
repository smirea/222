# Stack

- Language: Swift
- Package Manager: Swift Package Manager dependencies in `App.xcodeproj`
- Target: iOS 27 only (single user, latest OS only; Liquid Glass APIs need no availability checks). There is no Mac app and no Swift package; the Xcode project is the only build.
- Keep dependencies rare and intentional. The one dependency is Feedback (`https://github.com/smirea/feedback-engine`, branch `master`), shake-to-feedback.

# Development

- When you build or change a SwiftUI screen, row, card, or chart, follow Feedback's accessibility skill. Read the latest with `gh api repos/smirea/feedback-engine/contents/skills/feedback-accessibility/SKILL.md -H 'Accept: application/vnd.github.raw'`. Tag list rows with custom content through `.feedbackCell(self)` so the cell's padding selects the row. Trigger the editor on a simulator with `xcrun simctl notify_post <udid> com.apple.UIKit.SimulatorShake`, then press the button at (360, 92) by coordinates: a label press reports it covered and taps the screen center instead.
- The 222 token comes from env-manager project `222`. Run `env-manager down` before the first build; the Validate Secrets phase fails without it (CI skips the check). Never add sign-in UI.
- Run `./scripts/run` to build, install, and launch the app, with automatic rebuild and relaunch after saving. Requires Bun and Xcode. Stop with Ctrl-C, or use `--no-watch` for one launch.
- Use `./scripts/run --targets` to list devices and simulators; `*` marks the effective default. Select with `-t simulator` or `-t "iPhone 17"` (also accepts an identifier). It opens Device Hub on Xcode 27 or Simulator.app on earlier Xcode versions.
- Selection precedence is `-t` / `--target`, then `SWIFT_RUN_DEFAULT_TARGET`, then a connected iOS device, booted simulator, available simulator, or My Mac. Duplicate simulator names prefer a booted instance, then the newest runtime; use an identifier to select exactly. Add simulator runtimes in Xcode's settings.
- Agents run simulators headless: `./scripts/run -t "$(agent-simulator udid)" --headless` builds, installs, and launches without opening Simulator.app or Device Hub, booting the simulator while the app builds. `agent-simulator udid` creates and claims the worktree's own simulator, named after the worktree directory (`udid 2` for a second one). Never pick or create one with `xcrun simctl create`.
- When the launcher targets a simulator it runs `agent-simulator claim`, and before a headless boot `agent-simulator wait`, which holds the boot while the Mac is busy. Exit code 3 means rerun the same command. Both are skipped where `~/bin/agent-simulator` is missing, as in CI.
- Drive the simulator only with the command T3 Code's `device_open` returns, tapping by label (`press 'label="Save"' --settle`), and look at it with `device_screenshot`. Never write a wrapper around `simctl` or `idb` for taps or screenshots.
- Settling the thread, or merging its PR, stops and deletes the worktree's simulators. `agent-simulator stop` shuts them down earlier.
- `--pair-watch` pairs the simulator with a watch (the newest model on the newest watchOS, reusing an existing pair), boots both while the app builds, and installs and launches an embedded watch app. `./scripts/run -t <udid> --delete` (a udid only, never a name) shuts down and deletes the simulator and its paired watches; `simctl delete` of the phone alone leaves the watch behind.
- `./scripts/run` grants every `simctl privacy` service on a first install, so simulators start on the default, granted path. It skips later installs because the grant also resets HealthKit access. To test a denied state, run `xcrun simctl privacy <udid> revoke <service> <bundle id>` first. HealthKit has no `simctl` service.
- Physical devices need Xcode pairing, Developer Mode, and an unlocked screen. Configure automatic signing in Xcode, pass `--team`, or set `SWIFT_RUN_DEVELOPMENT_TEAM`.
- Edit SwiftUI code and resources in `Sources/App`; Xcode picks up new files automatically. Open `App.xcodeproj` and use the shared `App` scheme for debugging.
- Build errors leave the watcher running; fix the error and save again. Build output is in `DerivedData/device/build.log` or `DerivedData/simulator/build.log`.
- `xcodebuild build -project App.xcodeproj -scheme App -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` checks compilation.

# README

- `README.md` starts as the scaffold's placeholder. Once the project takes shape, rewrite it for this project and keep it short.
