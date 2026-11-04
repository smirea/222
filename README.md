<!--
Agents: this README is the scaffold's placeholder. Once the project is fleshed out, rewrite it for this project: what it is, how to run it, and the few things a newcomer must know. Keep it short, move component details into nested READMEs, and delete this comment.
-->

# 222

Created on 2026-11-04 with [setup-new-app](https://github.com/smirea/stefan-utils/tree/master/scripts/setup-new-app) (`--type swift`). `.github/CI.md` describes the CI checks.

SwiftUI app for iOS 17+ and macOS 14+. Requires Bun and Xcode 16 or newer.

```sh
./scripts/run               # build, launch, and relaunch on save
./scripts/run --targets     # list devices and simulators
./scripts/run -t simulator  # or -t mac, -t "iPhone 17"
```

Open `App.xcodeproj` with the shared `App` scheme to debug. Physical devices need signing: pass `--team YOUR_TEAM_ID` or set `SWIFT_RUN_DEVELOPMENT_TEAM`.

`AGENTS.md` covers target selection, simulators, and build logs.
