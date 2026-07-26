# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

rekie-sekie (歴積) is a native macOS menu-bar clipboard manager, using Clipy as its feature baseline (see `docs/spec_clipy_gap.md` for the up-to-date feature-gap analysis vs. Clipy and the phased implementation plan). Key constraints from `README.md`:

- Pure Swift/SwiftUI/AppKit — no web-technology wrapper.
- No network communication of any kind (no sync feature); everything is local-only.
- Distributed outside the App Store (direct distribution + notarization), since App Sandbox restrictions are incompatible with clipboard monitoring.

## Commands

```bash
swift build          # build
swift test            # run all tests
swift test --filter ClipboardMonitorTests   # run a single test target/class
swift run RekieSekie   # run the app locally
```

CI (`.github/workflows/`): `build.yml` runs `swift build` on push to `master`; `test.yml` runs `swift test` on pull requests. Both run on `macos-15`. Releases are automated via `release-please.yml` (see `.release-please-manifest.json` / `release-please-config.json` — versioning is intentionally kept below 1.0 for now).

## Architecture

**Entry point & app lifecycle**: `main.swift` creates the `NSApplication` and sets `AppDelegate` as delegate. `AppDelegate` runs the app as an accessory (`NSApp.setActivationPolicy(.accessory)`, no Dock icon) driven entirely from an `NSStatusItem` in the menu bar. It owns two `NSPopover`s (clipboard history and snippets), each shown in a transparent borderless `NSWindow` positioned at the current mouse location rather than anchored to the status item — this is what allows the popovers to appear "at the cursor" like Clipy. Global keyboard shortcuts (via `KeyboardShortcuts`, declared in `ShortcutName.swift`) toggle each popover; a local `NSEvent` monitor in `AppDelegate` maps arrow keys/digits 1–9/Enter/Escape to list navigation for whichever popover is open (`handleListKeyDown`), shared between history and snippets. Pasting is simulated (`PasteSimulator`) after re-activating the previously-frontmost app, since clipboard managers must give focus back before sending ⌘V.

**Clipboard monitoring**: `ClipboardMonitor` (`ObservableObject`, drives `ContentView` via `@Published items`) polls `NSPasteboard.general.changeCount` on a 0.5s `Timer` (added in `.common` run-loop mode so it keeps firing during popover tracking loops) rather than using any push-based API — there is no OS notification for pasteboard changes. On each detected change it:
1. Skips capture if the frontmost app's bundle identifier is in the user's excluded-apps list, or if `org.nspasteboard.ConcealedType` is present and concealed-type exclusion is enabled (password managers use this marker to opt out of clipboard history).
2. Captures either image data (TIFF) or string content — never both.
3. Deduplicates: if the new content matches an existing item, that item is moved to the front (`promoteToFront`, an UPDATE) instead of inserting a duplicate row. This "move existing entry to top on re-copy" behavior is a deliberate departure from Clipy (noted in `docs/spec_clipy_gap.md`).

Pasteboard access is abstracted behind the `PasteboardControlling` protocol (implemented by `NSPasteboard`) so `ClipboardMonitor` can be tested against `MockPasteboard` without touching the real system pasteboard.

**Persistence**: `Storage` wraps a single GRDB `DatabaseQueue` (SQLite at `Application Support/rekie-sekie/history.sqlite`, or an injectable path for tests). Schema migrations are registered incrementally in `Storage.migrator` (clipItem → +imageData column → snippet/snippetFolder tables) — new schema changes should be added as a new migration step, never by editing an existing one. On init, `Storage` also runs `deduplicateKeepingNewest()`, a one-time SQL cleanup (window function partitioned by `content, imageData`) that collapses any pre-existing duplicate rows down to the newest, since the app-level dedup logic above only prevents *new* duplicates going forward.

**Snippets**: `SnippetManager` (`ObservableObject`) is the read/write layer over `Snippet` and `SnippetFolder` records, independent of `ClipboardMonitor` but sharing the same `Storage`/database. `SnippetManager.displayOrder` (unfoldered snippets first, then per-folder) must stay in sync with however `SnippetsView` actually renders the list, since keyboard quick-select (digit/arrow keys) indexes into this array by position. `SnippetVariableExpander` expands `{date}`/`{time}`/`{datetime}` placeholders at paste time (not at snippet-save time).

**Preferences**: All user settings live in `Preferences` (a thin typed wrapper over `UserDefaults`), including `defaults` itself being swappable (`UserDefaults(suiteName:)`) so tests don't touch real user prefs. `LocalizationManager` is the one place that resolves which `Bundle` (`ja`/`en`/system-default lproj under `Bundle.module`) SwiftUI views should localize strings against; it's an `ObservableObject` so changing the language in Settings live-updates open views.

**Views**: `ContentView` (history) and `SnippetsView` (snippets) are the two popover bodies; `SettingsView` and `SnippetManagementView` are opened as standalone borderless `NSWindow`s (see the `openSettings`/`openSnippetManagement` pattern in `AppDelegate` — reused if adding another standalone window).

## Packaging & release (Phase 6)

`scripts/build-app.sh [version]` assembles a `RekieSekie.app` from a release build: it copies the executable plus every SwiftPM-generated resource bundle (`RekieSekie_RekieSekie.bundle`, and the ones GRDB/KeyboardShortcuts ship — `GRDB_GRDB.bundle`, `KeyboardShortcuts_KeyboardShortcuts.bundle`) into `Contents/Resources`, stamps the version into `Packaging/Info.plist`, and (unless `SKIP_ZIP=1`) zips the result with `ditto` (not plain `zip`, so a later signed build's code signature survives archiving) into `dist/`. Both dependencies link statically, so no dylibs need bundling — only their resources. The bundle identifier is `dev.nagumo.RekieSekie`.

**SwiftPM `Bundle.module` in a hand-assembled `.app` (important gotcha)**: SwiftPM's generated resource accessor only looks for a target's resource bundle at (1) `Bundle.main.bundleURL` directly (the `.app` root — where you *cannot* put resource bundles, since codesign rejects any content at the bundle root: "unsealed contents present in the bundle root"), and (2) the absolute `.build` path from the build machine (absent on any other machine). So a `swift build`-assembled `.app` crashes at runtime the moment any `Bundle.module` is touched. For our *own* code this is dodged in `LocalizationManager` (look under `Bundle.main.resourceURL` = `Contents/Resources` first, fall back to `.module`). For KeyboardShortcuts we can't edit its source (its `RecorderCocoa` calls `NSLocalizedString(_, bundle: .module)`, so opening the shortcut-recorder UI crashed), so `build-app.sh` renames its bundle to `Contents/Resources/KS.bundle` and binary-patches the standalone cstring `KeyboardShortcuts_KeyboardShortcuts.bundle` → `Contents/Resources/KS.bundle` in the executable (same-or-shorter, NUL-padded to preserve offsets; the accessor then resolves `Bundle.main.bundleURL + "Contents/Resources/KS.bundle"`, install-location-independent and signable). The patch runs before `install_name_tool`/signing, so the re-sign covers it. GRDB ships a bundle too but never reads it at runtime, so it needs no patch.

`.github/workflows/release-build.yml` runs whenever release-please publishes a GitHub Release (tag `vX.Y.Z`): it builds the `.app` unsigned (`SKIP_ZIP=1`), imports the `DEVELOPER_ID_CERT_P12` secret into a throwaway CI keychain, code-signs Sparkle's nested code (XPC services, `Autoupdate`, `Updater.app`) and the framework itself before `codesign --deep` on the app with Hardened Runtime (`Packaging/entitlements.plist`, currently an empty `<dict/>` — **entitlements plist must not contain XML comments**, Apple's AMFI parser rejects them with an opaque "syntax error"), notarizes via `notarytool` using the `AC_API_KEY_P8`/`AC_API_KEY_ID`/`AC_API_ISSUER_ID` App Store Connect API key secrets, staples the ticket, re-zips, and uploads the asset to the release. `TEAM_ID` (`99T9WYD3BF`) is also stored as a secret though the workflow currently matches the signing identity by the substring `"Developer ID Application"` (safe since the CI keychain only ever holds one imported identity). This whole chain was validated locally end-to-end (`spctl --assess` → `accepted, source=Notarized Developer ID`) before wiring it into CI.

**Sparkle auto-update**: Sparkle is added via SPM (`Package.swift`), unlike GRDB/KeyboardShortcuts it links dynamically (`@rpath/Sparkle.framework/...`), so `build-app.sh` additionally copies `Sparkle.framework` into `Contents/Frameworks` and adds an `@executable_path/../Frameworks` rpath to the executable via `install_name_tool`. `AppDelegate` owns an `SPUStandardUpdaterController` and wires a "アップデートを確認..." (Check for Updates...) item into the status-item context menu. `Packaging/Info.plist` carries `SUFeedURL` (`https://raw.githubusercontent.com/nagumo/rekie-sekie/master/docs/appcast.xml` — the appcast is served straight from the repo, no GitHub Pages needed) and `SUPublicEDKey` (the EdDSA public key from `generate_keys`; the matching private key is the `SPARKLE_PRIVATE_KEY` secret). **Gotcha**: Sparkle's own `generate_keys -x` export tool prepends a stray leading space to the exported key file — strip whitespace before storing it as a secret, or `sign_update`/`generate_appcast` reject it as "not base64 encoded" with no indication why.

After notarizing/stapling/uploading the zip, `release-build.yml` downloads the matching `Sparkle-X.Y.Z.tar.xz` release tarball (version read from `Package.resolved`, since the SPM binary distribution doesn't ship `generate_appcast`/`sign_update`/`generate_keys`) to get `bin/generate_appcast`, runs it against `docs/appcast.xml` + the new zip with `--ed-key-file -` (key piped from the secret) and `--download-url-prefix` pointing at this release's GitHub asset URL, then commits the regenerated `docs/appcast.xml` straight to `master` (checked out fresh via `git fetch`/`git checkout -B master origin/master`, since the triggering `release` event checks out a detached tag, not a branch).

## Security model (from README)

- No network access at all — do not add any networking dependency or code path.
- `org.nspasteboard.ConcealedType` detection must remain the primary defense against recording secrets copied from password managers; respect the existing on/off preference rather than hardcoding behavior.
