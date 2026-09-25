#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build/macos-arm64"

for tool in cmake ninja pkg-config; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
done

dependency_prefix="$("${repo_root}/tools/macos/build_dependencies.sh" | tail -1)"
export PKG_CONFIG_PATH="${dependency_prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

# Build LuaJIT with the Apple-Silicon JIT path (LUAJIT_ENABLE_OSX_HRT) and link
# against it. Homebrew's LuaJIT can't allocate JIT mcode in this app's layout,
# so the app would run interpreted at ~9 fps.
luajit_prefix="$("${repo_root}/tools/macos/build_luajit.sh")"

cmake -S "${repo_root}/macos" -B "${build_dir}" -G Ninja \
  -U 'pkgcfg_lib_SDL3_*' -U 'pkgcfg_lib_ZSTD_*' \
  -U 'SDL3_*' -U 'ZSTD_*' \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${dependency_prefix}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DLUAJIT_PREFIX="${luajit_prefix}"
cmake --build "${build_dir}"

echo "${build_dir}/PathOfBuilding-PoE2.app"
