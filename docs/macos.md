<!-- cspell:words pkgconf zstd otool vtool stevep -->

# Native macOS build

The first native macOS target is Apple Silicon (`arm64`) with a macOS 13 deployment target. The app uses a Cocoa/SDL3 host and the same Lua application data as the Windows build. Intel Macs and in-app automatic updates are not yet supported.

## Build locally

Install Xcode Command Line Tools and these build tools:

```sh
brew install cmake ninja pkgconf
```

From the repository root, run:

```sh
tools/macos/build_app.sh
tools/macos/package_app.sh
```

The build scripts download pinned SDL3, zstd, and LuaJIT source releases into the ignored `build/` directory. They verify the SDL3 and zstd source archives, build their libraries for macOS 13, and build LuaJIT with `LUAJIT_ENABLE_OSX_HRT` for Apple Silicon JIT support. The packaging step verifies the font assets against `manifest.xml`, bundles native libraries, and writes:

```text
dist/macos-arm64/Path of Building (PoE2).app
dist/macos-arm64/PathOfBuilding-PoE2-macos-arm64.zip
dist/macos-arm64/PathOfBuilding-PoE2-macos-arm64.zip.sha256
```

The ZIP is the distributable artifact. It contains the Lua application, fonts, and all non-system libraries. It must launch without Homebrew or the source checkout. The `macos.yml` workflow builds the same artifact on an Apple Silicon runner.

For a stable release package, set `POB_BRANCH=master` when running `package_app.sh`; the default is `dev`. The bundle-local manifest records that branch and `platform="macos-arm64"`. The root manifest and Windows runtime are left intact.

## Install and update

Unzip the release asset and move **Path of Building (PoE2).app** to Applications. Builds and settings are stored under `~/Library/Application Support/Path of Building (PoE2)/`, outside the app bundle. Replacing the app with a newer release keeps those files. The Check for Update button opens the project Releases page; macOS does not use the Windows `Update.exe` flow.

Public releases should be signed and notarized by `macos-release.yml`. CI artifacts from pull requests are unsigned and intended for testing.

## Validation

Run the Lua tests through the existing `test.yml` workflow. Before releasing, test the **packaged** app on a Mac without Homebrew and on macOS 13:

- Launch, resize, switch tabs, inspect tooltips, and navigate the passive tree.
- Save and reopen a build; confirm it is under Application Support.
- Paste an in-game item; generate and import a build share code.
- Open browser links, use trade/API requests, and complete account sign-in.
- Check keyboard shortcuts, especially attribute-node hotkeys.
- Replace an older app with a newer ZIP and verify builds and settings survive.

Use `otool -L` and `vtool -show-build` on the executable and bundled libraries to verify that no Homebrew path remains and that their minimum macOS version is at most 13.0.

The native host is adapted from [PoE2 PR #2213](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/2213) and [stevep51's macOS port](https://github.com/stevep51/PathOfBuilding-PoE2-MacOS), under their stated MIT licensing.
