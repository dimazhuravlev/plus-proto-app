#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/recently-history.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Data/VibeStation.swift" \
    "$repo_dir/PlusProtoApp/State/RecentlyConsumed.swift" \
    "$repo_dir/PlusProtoApp/Showcase/RecentlyMovieTime.swift" \
    "$repo_dir/Tests/RecentlyIdentityChecks.swift" -o "$check_dir/checks"
"$check_dir/checks"
