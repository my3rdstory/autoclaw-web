#!/usr/bin/env bash
set -euo pipefail

# Version helpers (semver-ish).
# Works for simple x.y.z comparisons.

ver_norm() {
  # strip leading v and keep digits/dots
  echo "$1" | sed -E 's/^v//' | sed -E 's/[^0-9.].*$//'
}

# Compare versions using dpkg (available on ubuntu/debian)
ver_ge_dpkg() {
  local a b
  a="$(ver_norm "$1")"
  b="$(ver_norm "$2")"
  [[ -z "$a" || -z "$b" ]] && return 1
  dpkg --compare-versions "$a" ge "$b"
}
