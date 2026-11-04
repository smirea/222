# Stack

- Language: Swift
- Package Manager: Swift Package Manager
- Minimum targets: iOS 27 and macOS 27 (single user, latest OS only; Liquid Glass APIs need no availability checks)
- Keep dependencies rare and intentional

# Development

- Run `./scripts/run` to build, install, and launch the app, with automatic rebuild and relaunch after saving. Requires Bun and Xcode. Stop with Ctrl-C, or use `--no-watch` for one launch.
- Use `./scripts/run --targets` to list devices and simulators; `*` marks the effective default. Select with `-t simulator`, `-t mac`, or `-t "iPhone 17"` (also accepts an identifier). It opens Device Hub on Xcode 27 or Simulator.app on earlier Xcode versions.
- Selection precedence is `-t` / `--target`, then `SWIFT_RUN_DEFAULT_TARGET`, then a connected iOS device, booted simulator, available simulator, or My Mac. Duplicate simulator names prefer a booted instance, then the newest runtime; use an identifier to select exactly. Add simulator runtimes in Xcode's settings.
- Agents run simulators headless: `./scripts/run -t "$(agent-simulator udid)" --headless` builds, installs, and launches without opening Simulator.app or Device Hub, booting the simulator while the app builds. `agent-simulator udid` creates and claims the worktree's own simulator, named after the worktree directory (`udid 2` for a second one). Never pick or create one with `xcrun simctl create`.
- When the launcher targets a simulator it runs `agent-simulator claim`, and before a headless boot `agent-simulator wait`, which holds the boot while the Mac is busy. Exit code 3 means rerun the same command. Both are skipped where `~/bin/agent-simulator` is missing, as in CI.
- Drive the simulator only with the command T3 Code's `device_open` returns, tapping by label (`press 'label="Save"' --settle`), and look at it with `device_screenshot`. Never write a wrapper around `simctl` or `idb` for taps or screenshots.
- Settling the thread, or merging its PR, stops and deletes the worktree's simulators. `agent-simulator stop` shuts them down earlier.
- `--pair-watch` pairs the simulator with a watch (the newest model on the newest watchOS, reusing an existing pair), boots both while the app builds, and installs and launches an embedded watch app. `./scripts/run -t <udid> --delete` (a udid only, never a name) shuts down and deletes the simulator and its paired watches; `simctl delete` of the phone alone leaves the watch behind.
- `./scripts/run` grants every `simctl privacy` service on a first install, so simulators start on the default, granted path. It skips later installs because the grant also resets HealthKit access. To test a denied state, run `xcrun simctl privacy <udid> revoke <service> <bundle id>` first. HealthKit has no `simctl` service.
- Physical devices need Xcode pairing, Developer Mode, and an unlocked screen. Configure automatic signing in Xcode, pass `--team`, or set `SWIFT_RUN_DEVELOPMENT_TEAM`.
- Edit SwiftUI code and resources in `Sources/App`; Xcode picks up new files automatically. Open `App.xcodeproj` and use the shared `App` scheme for debugging.
- Build errors leave the watcher running; fix the error and save again. Build output is in `DerivedData/device/build.log`, `DerivedData/simulator/build.log`, or `DerivedData/mac/build.log`.
- `swift build` checks the shared code on macOS. Use the Xcode project for simulator builds and bundled resources; `swift run` launches the macOS executable.

# README

- `README.md` starts as the scaffold's placeholder. Once the project takes shape, rewrite it for this project and keep it short.
