#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/home-recently-pull.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/HomeRecentlyPullPolicy.swift" \
    "$repo_dir/Tests/HomeRecentlyPullChecks.swift" \
    -o "$check_dir/checks"
"$check_dir/checks"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/HomeRecentlyCenterAnchor.swift" \
    "$repo_dir/Tests/HomeRecentlyCenterChecks.swift" \
    -o "$check_dir/center-checks"
"$check_dir/center-checks"
