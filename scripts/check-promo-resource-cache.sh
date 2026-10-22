#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/promo-resource-cache.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoResourceCache.swift" \
    "$repo_dir/Tests/PromoResourceCacheChecks.swift" \
    -o "$check_dir/checks"
"$check_dir/checks"
