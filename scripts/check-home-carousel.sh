#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/home-carousel.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoCarouselSpacing.swift" \
    "$repo_dir/Tests/PromoCarouselSpacingChecks.swift" -o "$check_dir/spacing"
"$check_dir/spacing"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoViewportSizing.swift" \
    "$repo_dir/PlusProtoApp/Showcase/PromoCarouselGeometry.swift" \
    "$repo_dir/Tests/PromoCarouselGeometryChecks.swift" -o "$check_dir/geometry"
"$check_dir/geometry"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoTaskDeadline.swift" \
    "$repo_dir/Tests/PromoTaskDeadlineChecks.swift" -o "$check_dir/deadline"
"$check_dir/deadline"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Data/PromoCuratedContent.swift" \
    "$repo_dir/Tests/PromoCuratedContentChecks.swift" -o "$check_dir/curated"
"$check_dir/curated"
swiftc -swift-version 5 -module-cache-path "$check_dir/module-cache" \
    "$repo_dir/PlusProtoApp/Showcase/PromoPetalWave.swift" \
    "$repo_dir/Tests/PromoPetalWaveChecks.swift" -o "$check_dir/petal-wave"
"$check_dir/petal-wave"
