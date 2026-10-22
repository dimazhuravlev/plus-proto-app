#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/toast-center.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -parse-as-library -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/State/ToastCenter.swift" \
    "$repo_dir/Tests/ToastCenterChecks.swift" -o "$check_dir/checks"
"$check_dir/checks"
