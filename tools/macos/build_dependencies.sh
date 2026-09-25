#!/usr/bin/env bash
# Build the shipped SDL3 and zstd libraries for the minimum supported macOS.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
base="${repo_root}/build/dependencies"
sources="${base}/sources"
prefix="${base}/macos-arm64"
mkdir -p "${sources}"

fetch_source() {
  local name="$1" url="$2" sha="$3"
  local archive="${sources}/${name}.tar.gz"
  if [ ! -f "${archive}" ]; then
    curl -fL --retry 3 --silent --show-error "${url}" -o "${archive}"
  fi
  printf '%s  %s\n' "${sha}" "${archive}" | shasum -a 256 -c - >/dev/null
  if [ ! -d "${sources}/${name}" ]; then
    tar -xzf "${archive}" -C "${sources}"
  fi
}

fetch_source "SDL3-3.4.16" \
  "https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz" \
  "7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68"
fetch_source "zstd-1.5.7" \
  "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz" \
  "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"

cmake -S "${sources}/SDL3-3.4.16" -B "${base}/sdl-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_INSTALL_PREFIX="${prefix}" \
  -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF
cmake --build "${base}/sdl-build" --parallel
cmake --install "${base}/sdl-build"

cmake -S "${sources}/zstd-1.5.7/build/cmake" -B "${base}/zstd-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_INSTALL_PREFIX="${prefix}" \
  -DZSTD_BUILD_SHARED=ON -DZSTD_BUILD_STATIC=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF
cmake --build "${base}/zstd-build" --parallel
cmake --install "${base}/zstd-build"

echo "${prefix}"
