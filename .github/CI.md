# Continuous integration

`workflows/ci.yml` runs on pull requests, default-branch pushes, and manual dispatches. Every check is its own job and the jobs run in parallel, so a run takes as long as its slowest check. A newer push to the same branch or pull request cancels the run in progress. All CI helpers run with Bun, pinned by `.bun-version`.

Actions are pinned to commit SHAs. Dependabot checks for action updates weekly.

This repository has no root package and no Bun jobs. CI never installs or runs env-manager. The Validate Secrets build phase exits immediately when `CI` is set, so the jobs do not need `TWOTWOTWO_API_KEY`. Locally, `env-manager down` writes the gitignored `Config/LocalSecrets.xcconfig`.

The app is iOS only and has no Swift package. `checks` compiles the shared `App` scheme in Debug, and `build` compiles it in Release, both for a generic iOS simulator without signing. `tests` runs Xcode testables or test plans when the scheme has them; with none, the job passes. Xcode tests use an available iPhone simulator. Each task runs `scripts/own-packages.ts` first. That moves the owner's branch pins, including Feedback, to the branch head. Offline, the pin stays.

The Swift jobs wait for `changes`, which reads the diff so they take GitHub's `xcode-27` image only when native inputs changed. Otherwise each reports success from a Linux runner, which keeps a required check green. Manual dispatches, initial pushes, and force-pushes whose base commit is gone run them, and so do workflow changes. Documentation changes don't. Edit `scripts/changes.ts` when the layout changes. A failure in change detection fails the Swift jobs too. Native jobs use the image's installed Xcode and Swift. `Package.resolved` is untracked, so the package cache key includes the workflow run id. A key that hashed the pin file would reuse a stale checkout whenever `scripts/own-packages.ts` cannot reach GitHub.

Configure branch protection to require the generated job names you need. After renaming the default branch, update the workflow's push branch.
