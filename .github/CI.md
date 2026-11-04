# Continuous integration

`workflows/ci.yml` runs checks, tests, and builds on pull requests, default-branch pushes, and manual dispatches. Each task reports success when its stack has no relevant changes. Manual dispatches and initial pushes run every configured task. Documentation changes are ignored; workflow changes run every task. Edit `scripts/changes.ts` when adding a new component or changing the layout. All CI helpers run with Bun, pinned by `.bun-version`, including Swift and empty scaffolds.

Actions are pinned to commit SHAs. Dependabot checks for action updates weekly. A failure in change detection fails the task jobs too.

Bun tasks run the root `lint:ci` and `typecheck`, `test`, and `build` scripts. Keep CI checks read-only. Tests pass until tests are added, and failures then fail CI. `.bun-version` and `packageManager` pin Bun to the version used during scaffolding; update them together. Commit `bun.lock` after changing dependencies. CI caches package downloads, then always installs with `--frozen-lockfile`.

Apps using env-manager regenerate ignored outputs from the tracked `.env` defaults with the pinned development dependency. Keep defaults harmless and complete enough for CI. If a test needs a credential, supply it explicitly through GitHub Actions secrets. Never commit `.env.local` or native local secrets, and never cache environment outputs.

The app is iOS only and has no Swift package. Checks compile the shared `App` Xcode scheme in Debug and builds in Release, both for a generic iOS simulator without signing. Tests run Xcode testables or test plans when configured; no test targets passes. Xcode tests use an available iPhone simulator. Native jobs use the macOS runner's installed Xcode and Swift, and cache only package dependencies with a key including both toolchain versions. Commit `App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` when adding dependencies.

Empty scaffolds have successful placeholder tasks. Replace them with real commands when choosing a stack. Configure branch protection to require the generated task names you need. After renaming the default branch, update the workflow's push branch.
