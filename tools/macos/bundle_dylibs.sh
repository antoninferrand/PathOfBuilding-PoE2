#!/usr/bin/env bash
# Copy the three native dependencies and make all executable references local.
set -euo pipefail

app="${1:?usage: bundle_dylibs.sh <path-to-.app>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exe="${app}/Contents/MacOS/PathOfBuilding-PoE2"
frameworks="${app}/Contents/Frameworks"
dependency_lib="${repo_root}/build/dependencies/macos-arm64/lib"
luajit_lib="${repo_root}/build/luajit/lib"

mkdir -p "${frameworks}"
cp -L "${dependency_lib}/libSDL3.0.dylib" "${frameworks}/libSDL3.0.dylib"
cp -L "${dependency_lib}/libzstd.1.dylib" "${frameworks}/libzstd.1.dylib"
cp -L "${luajit_lib}/libluajit-5.1.2.dylib" "${frameworks}/libluajit-5.1.2.dylib"

install_name_tool \
  -change '@rpath/libSDL3.0.dylib' '@executable_path/../Frameworks/libSDL3.0.dylib' \
  -change '@rpath/libzstd.1.dylib' '@executable_path/../Frameworks/libzstd.1.dylib' \
  -change "${luajit_lib}/libluajit-5.1.2.dylib" '@executable_path/../Frameworks/libluajit-5.1.2.dylib' \
  -delete_rpath "${dependency_lib}" \
  -delete_rpath "${luajit_lib}" \
  "${exe}"
install_name_tool -id '@executable_path/../Frameworks/libluajit-5.1.2.dylib' \
  "${frameworks}/libluajit-5.1.2.dylib"

for binary in "${frameworks}"/*.dylib "${exe}"; do
  codesign --force --sign - "${binary}"
  codesign --verify --strict "${binary}"
  if ! file "${binary}" | grep -q 'arm64'; then
    echo "Wrong architecture in ${binary}" >&2
    exit 1
  fi
  minos="$(vtool -show-build "${binary}" | awk '/minos / { print $2; exit }')"
  if [ -z "${minos}" ] || [ "${minos%%.*}" -gt 13 ]; then
    echo "Unsupported minimum macOS version ${minos:-unknown} in ${binary}" >&2
    exit 1
  fi
  if otool -L "${binary}" | grep -Eq '/opt/homebrew/|/usr/local/|/opt/local/|/build/'; then
    echo "Unbundled dependency in ${binary}" >&2
    exit 1
  fi
done

if otool -l "${exe}" | grep -Eq 'path /opt/homebrew/|path /usr/local/|path /opt/local/|path .*/build/'; then
  echo "Executable still has a build-machine LC_RPATH" >&2
  exit 1
fi

echo "Bundled SDL3, zstd, and LuaJIT without build-machine paths"
