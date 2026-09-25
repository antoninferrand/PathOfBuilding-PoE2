# ADR 0001: Native macOS builds

- Status: Accepted (implementation in progress; release validation pending)
- Date: 2026-09-25
- Scope: Path of Building for Path of Exile 2

## Context

The repository contains a Lua application and a Windows runtime in `runtime/`. Its executable, SimpleGraphic host, and native Lua modules are Windows PE files. The release workflow in `.github/workflows/installer.yml` invokes the separate Windows installer repository. macOS users therefore do not receive a native application from this repository.

The Lua application depends on functions supplied by SimpleGraphic; `src/_SimpleGraphic.def.lua` lists their signatures. `src/Launch.lua` controls startup and updates. `src/Modules/Main.lua` chooses where user data is stored. `src/UpdateCheck.lua`, `src/UpdateApply.lua`, `manifest.cfg`, and `update_manifest.py` assume the current Windows runtime and update layout.

A working Apple Silicon port has been reported in [PoE2 PR #2213](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/2213). It draws its host from [stevep51's macOS port](https://github.com/stevep51/PathOfBuilding-PoE2-MacOS). The PR is useful implementation material, but its branch also removes Windows runtime files and includes unrelated changes. It targets an older PoE2 application revision than this checkout. It must be adapted file by file rather than merged wholesale.

## Decision

Ship a native Apple Silicon `.app` for macOS 13 or newer, distributed as a ZIP alongside the existing Windows release assets. Keep the Windows runtime, installer, tests, and update process intact. The first macOS release will use manual updates through the official Releases page. It will not attempt to modify a running or signed app bundle.

Intel and universal binaries, a DMG, and automatic macOS updates are follow-up work. They are not conditions for the initial Apple Silicon release.

## Implementation sequence

### 1. Adapt the native host

1. Compare PR #2213 with the current `dev` branch. Import only its `macos/` host, `tools/macos/` build and package scripts, macOS workflow and documentation patterns, and necessary Lua compatibility changes. Keep the current `src/Data`, calculation code, Windows binaries, and release workflows. Preserve the original port's license and attribution.
2. Build the host with CMake and Ninja for `arm64`. Use the Cocoa/SDL3 window and renderer from the port, with the existing Lua application under `Contents/Resources/src`. Verify each SimpleGraphic API used by the application against `src/_SimpleGraphic.def.lua`, especially rendering, input, clipboard, file operations, `OpenURL`, `GetScriptPath`, `GetRuntimePath`, `GetUserPath`, `LaunchSubScript`, and process spawning. Implement missing functions in the host rather than replacing application behavior with stubs.
3. Pin LuaJIT and build it with `LUAJIT_ENABLE_OSX_HRT`. PR #2213 reports that omitting the Apple Silicon hardened-runtime JIT path caused severe performance loss. Build or bundle `lcurl`, `lzip`, and `lua-utf8` against the same LuaJIT ABI. Verify other native modules actually loaded by the packaged app, including the loopback socket used for sign-in.
4. Inspect the current manifest for `SimpleGraphic/Fonts` entries. Make the build obtain both `.tga` atlases and `.tgf` metadata, verify their hashes or pinned source, and include them in the app. A clean checkout must not depend on fonts left by an earlier install.

**Exit check:** `tools/macos/build_app.sh` produces `build/macos-arm64/PathOfBuilding-PoE2.app` from a clean checkout, and launching it loads the UI with fonts and passive-tree graphics.

### 2. Assemble a portable app bundle

Create `tools/macos/package_app.sh` to place the executable in `Contents/MacOS`, native libraries in `Contents/Frameworks`, and Lua files, assets, fonts, license, changelog, and manifest in `Contents/Resources`. Exclude development-only files such as `src/Export`, `src/Builds`, `src/HeadlessWrapper.lua`, and `src/LaunchInstall.lua`. Set the host's working directory and Lua search paths explicitly so launching from Finder works, regardless of the caller's directory.

Bundle non-system dynamic libraries and rewrite install names to bundle-relative paths. Fail packaging if `otool -L` still shows Homebrew or developer-machine paths, if an expected library is missing, or if duplicate `LC_RPATH` entries remain. PR #2213 documents both a Homebrew dependency leak and a duplicate-rpath launch crash. Produce `dist/macos-arm64/PathOfBuilding-PoE2-macos-arm64.zip` with `ditto` and a corresponding SHA-256 file. Keep generated app bundles, build directories, and release archives out of Git.

The app's user data belongs in `~/Library/Application Support/Path of Building (PoE2)/`. Adjust the macOS host's `GetUserPath` and the portable-mode condition in `src/Modules/Main.lua` so an installed `.app` never saves builds or settings inside `Contents/Resources`. Test replacing the app bundle without changing that data directory. Do not silently migrate or delete existing user data.

**Exit check:** the ZIP launches on an Apple Silicon Mac without Homebrew or a source checkout; a saved build remains available after replacing the app with a newer ZIP.

### 3. Make the first release manifest and update behavior safe

Generate a bundle-local `manifest.xml` from the current repository version. Its `<Version>` must include `platform="macos-arm64"` and the intended branch (`master` for a stable release, `dev` for development builds). This prevents the packaged app from being treated as a source checkout. Preserve the repository's Windows manifest and Windows runtime entries.

For macOS, bypass every path that invokes the Windows updater: first-run update, startup background check, periodic check, manual update action, and `Launch.lua:ApplyUpdate`. The visible “Check for Update” action should open this repository's Releases page. If the UI exposes branch switching, make its behavior explicit for macOS and avoid writing the signed bundle's manifest. Leave `UpdateCheck.lua` and `UpdateApply.lua` unchanged for Windows unless a shared change is necessary.

Do not add the `.app` to the current repository-wide manifest generator as a single runtime file. `update_manifest.py` currently labels runtime sources `win32`, identifies Windows binaries by extension, and the updater applies individual runtime files through `Update.exe`. A future macOS updater needs its own bundle replacement, validation, signature, and rollback design.

**Exit check:** the packaged app displays the correct version, uses the macOS user-data location, and neither starts `Update.exe` nor attempts in-place writes to its bundle.

### 4. Add CI and release publishing

Add `.github/workflows/macos.yml` for pull requests to `dev`, pushes to `dev`, and manual runs. Pin an Apple Silicon macOS runner and install the documented build dependencies. Run the build and package scripts, validate the bundle's architecture and dynamic-library paths, verify the ZIP checksum, and upload the ZIP plus checksum as CI artifacts. Keep `.github/workflows/test.yml` running the existing Lua suite; add a native GUI smoke test where the runner can launch an app.

Add a macOS release job that checks out the exact release tag and uploads the macOS ZIP and checksum to the **same GitHub Release** that receives the Windows assets. Avoid a separate macOS tag scheme unless maintainers later choose independent release timing. Keep the existing Windows installer job and its triggers working.

For public releases, sign bundled libraries and the app with Developer ID, enable the hardened-runtime entitlements required by LuaJIT, notarize, staple, and verify the final ZIP after signing. Signing credentials belong only in release-job secrets. Pull-request builds may remain unsigned. The release job must fail clearly when public signing is required but credentials or notarization are unavailable; it must not silently publish an unnotarized asset as an official macOS release.

**Exit check:** a release tag produces both Windows and macOS assets from the intended revision, and the macOS asset launches on a clean Mac through the normal Finder installation flow.

### 5. Validate application behavior and document it

Run the existing Lua tests and perform these checks against the **packaged** app, not only a build-tree executable:

- Launch, resize, redraw, switch tabs, inspect tooltips, and navigate the passive tree.
- Create a build, save it, restart, and reopen it from Application Support.
- Paste an item from the game; generate and import a build share code.
- Use trade/API requests, browser links, and the account sign-in callback.
- Check keyboard shortcuts, including attribute-node hotkeys. PR #2213 found a case mismatch between the host and Lua code.
- Launch on a Mac without Homebrew; verify no libraries are loaded from `/opt/homebrew` or a build directory.
- Replace an older `.app` with a newer release and confirm builds and settings survive.
- Run the existing Windows build and update checks after the macOS changes.

Update `README.md`, `CONTRIBUTING.md`, and `RELEASE.md` with the supported architecture and macOS version, local build commands, ZIP installation, data location, and manual update process. State plainly that Intel Macs are not covered by the first artifact.

## Completion criteria

This ADR is implemented when a clean Apple Silicon macOS 13+ machine can install and run the released app without Wine, Windows binaries, Homebrew, or a source checkout; core app and network features pass the checks above; release artifacts are signed and notarized; and Windows release and update behavior still passes its existing gates.

## Follow-up decisions

Decide separately whether to add an Intel or universal build, and whether macOS should support automatic updates. An updater proposal must define bundle-level replacement, signature verification, rollback, and how `manifest.cfg`, `update_manifest.py`, and `src/UpdateCheck.lua` represent platform-specific runtime files without exposing macOS to Windows update operations.
