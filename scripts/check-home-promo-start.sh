#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/home-promo-start.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/HomePromoStartPolicy.swift" \
    "$repo_dir/Tests/HomePromoStartChecks.swift" -o "$check_dir/checks"
"$check_dir/checks"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoSwipeHapticPolicy.swift" \
    "$repo_dir/Tests/PromoSwipeHapticChecks.swift" -o "$check_dir/haptic-checks"
"$check_dir/haptic-checks"
