#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build/macos-arm64"
dist_dir="${repo_root}/dist/macos-arm64"
app_src="${build_dir}/PathOfBuilding-PoE2.app"
app_dst="${dist_dir}/Path of Building (PoE2).app"

"${repo_root}/tools/macos/fetch_fonts.sh"
"${repo_root}/tools/macos/build_app.sh"

mkdir -p "${dist_dir}"
rm -rf "${app_dst}"
cp -R "${app_src}" "${app_dst}"

resources="${app_dst}/Contents/Resources"
mkdir -p "${resources}"
rsync -a --delete \
  --exclude 'Export' \
  --exclude 'Builds' \
  --exclude 'Settings.xml' \
  --exclude 'HeadlessWrapper.lua' \
  --exclude 'LaunchInstall.lua' \
  "${repo_root}/src/" "${resources}/src/"

mkdir -p "${resources}/runtime/SimpleGraphic/Fonts"
rsync -a "${repo_root}/runtime/SimpleGraphic/Fonts/" "${resources}/runtime/SimpleGraphic/Fonts/"
mkdir -p "${resources}/runtime/lua"
rsync -a "${repo_root}/runtime/lua/" "${resources}/runtime/lua/"
version="$(python3 "${repo_root}/tools/macos/make_manifest.py" \
  "${repo_root}/manifest.xml" "${resources}/manifest.xml" --branch "${POB_BRANCH:-dev}")"
if [ -n "${POB_EXPECTED_VERSION:-}" ] && [ "${version}" != "${POB_EXPECTED_VERSION#v}" ]; then
  echo "Manifest version ${version} does not match release ${POB_EXPECTED_VERSION}" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${app_dst}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version%%-*}" "${app_dst}/Contents/Info.plist"
cp "${repo_root}/changelog.txt" "${resources}/changelog.txt"
cp "${repo_root}/help.txt" "${resources}/help.txt"
cp "${repo_root}/LICENSE.md" "${resources}/LICENSE.md"
mkdir -p "${resources}/ThirdPartyLicenses"
cp "${repo_root}/build/dependencies/sources/SDL3-3.4.16/LICENSE.txt" "${resources}/ThirdPartyLicenses/SDL3.txt"
cp "${repo_root}/build/dependencies/sources/zstd-1.5.7/LICENSE" "${resources}/ThirdPartyLicenses/zstd.txt"
cp "${repo_root}/build/luajit-src/COPYRIGHT" "${resources}/ThirdPartyLicenses/LuaJIT.txt"

# Add the native libraries and sign only after Info.plist and bundle resources
# have their final contents. Changing Info.plist after signing invalidates the
# executable's signature, even when verifying the executable by itself.
"${repo_root}/tools/macos/bundle_dylibs.sh" "${app_dst}"
codesign --verify --strict --deep "${app_dst}"

zip_name="PathOfBuilding-PoE2-macos-arm64.zip"
ditto -c -k --keepParent "${app_dst}" "${dist_dir}/${zip_name}"

# Publish a SHA-256 checksum next to the zip so users can verify the download
# (see SECURITY.md). Generated with the filename only so it works with
# `shasum -a 256 -c PathOfBuilding-PoE2-macos-arm64.zip.sha256` from the
# directory containing the zip.
(
  cd "${dist_dir}"
  shasum -a 256 "${zip_name}" > "${zip_name}.sha256"
)

echo "${dist_dir}/${zip_name}"
echo "${dist_dir}/${zip_name}.sha256"
