#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "${repo_root}/tools/macos/verify_fonts.py" "${repo_root}"
