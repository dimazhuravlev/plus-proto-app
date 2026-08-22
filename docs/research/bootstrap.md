# Bootstrap recipe: sibling Xcode project of /Users/dimazhuravlev/Repos/MusicPlayer

## VERIFIED end-to-end on this machine (2026-08-22): copied pbxproj + sed rename + 7 stub files → `xcodebuild` BUILD SUCCEEDED, including remote SPM resolution and `import VariableBlur`.

## Toolchain on this machine
- Xcode 26.3 (Build 17C529), at /Applications/Xcode.app
- Simulator runtimes: iOS 26.2, iOS 26.0, iOS 18.6, iOS 17.5
- **iPhone 17 Pro (iOS 26.0) is currently Booted**, UDID `3DF755B7-31A1-48B9-8249-7002AF45AB80`. Also available: iPhone 17 Pro Max, iPhone Air, iPhone 17, iPhone 16e (26.x), full iPhone 15/16 lineups on 17.5/18.6.

## Key facts from MusicPlayer.xcodeproj/project.pbxproj
- `objectVersion = 77`, `preferredProjectObjectVersion = 77` (project.pbxproj:6,106) — **modern filesystem-synchronized format**. Sources are a single `PBXFileSystemSynchronizedRootGroup` (`path = MusicPlayer`, project.pbxproj:17-23); **zero per-file references** — everything under `MusicPlayer/` is auto-membered (Swift → Sources, .metal → compiled, .otf/.ttf/.wav/.mov/.webm/.ahap/.xcassets → Resources). No `PBXFileSystemSynchronizedBuildFileExceptionSet` exists, so no exceptions to replicate. Whole pbxproj is only 15 KB / 393 lines. Adding files later = just create them on disk, no project edits.
- `IPHONEOS_DEPLOYMENT_TARGET = 18.5` (project.pbxproj:285,331); also `MACOSX_DEPLOYMENT_TARGET = 15.5`, `XROS_DEPLOYMENT_TARGET = 2.5`, but `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` (iOS-only in practice). `TARGETED_DEVICE_FAMILY = "1,2,7"`. `SDKROOT = auto`.
- `SWIFT_VERSION = 5.0` (project.pbxproj:297). CreatedOnToolsVersion 16.4, LastUpgradeCheck 2600.
- Bundle id: `PRODUCT_BUNDLE_IDENTIFIER = com.dima.MusicPlayer123` (project.pbxproj:290) — pattern `com.dima.<Name>` (the `123` suffix is arbitrary junk; for the new app use e.g. `com.dima.YandexPlus`).
- Signing: `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY = "Apple Development"`, `DEVELOPMENT_TEAM = Z55ZV5538M` (set at both project- and target-level configs: lines 173,237,267,313). `CODE_SIGN_ENTITLEMENTS = MusicPlayer/MusicPlayer.entitlements`. Simulator builds sign with "Sign to Run Locally" — team identity not exercised for sim builds (verified). `ENABLE_APP_SANDBOX = YES`, `ENABLE_HARDENED_RUNTIME = YES`, `ENABLE_USER_SELECTED_FILES = readonly`, `REGISTER_APP_GROUPS = YES`.
- Info.plist strategy: `GENERATE_INFOPLIST_FILE = YES` + `INFOPLIST_FILE = Info.plist` (repo-root file, merged in). Root /Users/dimazhuravlev/Repos/MusicPlayer/Info.plist contains ONLY `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` (needed for arbitrary mock/public API hosts). Everything else via `INFOPLIST_KEY_*` build settings: `INFOPLIST_KEY_CFBundleDisplayName = Music` (project.pbxproj:274), scene manifest generation, launch screen generation, orientations. **There is no target-level Info.plist file.**
- Entitlements (MusicPlayer/MusicPlayer.entitlements): single key `com.apple.security.network.client = true`.

## VariableBlur linkage — CORRECTION to task premise
It is **NOT a local package reference**. pbxproj uses `XCRemoteSwiftPackageReference` → `https://github.com/nikstar/VariableBlur`, `kind = branch, branch = main` (project.pbxproj:372-381), plus `XCSwiftPackageProductDependency` (383-389), `packageProductDependencies` on the target (72-74), and one `PBXBuildFile` in Frameworks (10). The repo-root `VariableBlur/` directory is a gitignored local checkout that the project does NOT reference — scratch only. Pinned revision in `MusicPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`: `c8dc0ada195dfd47354cec5994c2dd434aa6c146`. Fresh resolution today fetches `5073a0d` (newer main) — verified it still compiles `VariableBlurView(maxBlurRadius:)`. To pin identically, copy Package.resolved into the new project's `project.xcworkspace/xcshareddata/swiftpm/`. GitHub SPM resolution works on this machine (no corporate-TLS blocker for this repo).

## Fonts — NOT UIAppFonts
No `UIAppFonts`/`INFOPLIST_KEY_UIAppFonts` anywhere. Fonts (`MusicPlayer/Fonts/YangoGroupHeadlineAR-ExtraBold.otf`, `YangoText-Medium.ttf`) are bundled automatically by the synced group and registered **at runtime** via `CTFontManagerRegisterFontsForURL(_, .process, _)` in /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/FontManager.swift:9-34, called from `MusicApp.init()` (MusicPlayer/MusicApp.swift:12). Typed accessors in MusicPlayer/Fonts/CustomFonts.swift (`Font.Headline1…5`, `Title1/2`, `Text1/2/3`). Replicate this pattern for the new app; no plist work needed.

## Bundled resources pattern (all auto-membered via synced group, zero pbxproj entries)
- Videos: `MusicPlayer/Videos/*.mov|*.webm`; also `.mov` inside an asset-catalog `.dataset` (Assets.xcassets/Shader.dataset/New_shader.mov)
- Sounds: `MusicPlayer/Sounds/offline_transition.wav`
- Haptics: `MusicPlayer/CustomHaptic.ahap`
- Metal: `MusicPlayer/Shaders/OfflineFlash.metal`, `MusicPlayer/Glow Button/Shaders/Gradient.metal` (+ `Shared.h`) — compiled automatically
- Asset catalog `MusicPlayer/Assets.xcassets` with AppIcon.appiconset, AccentColor.colorset, nested folders (albums/, artists/, yasmina/, wizard covers/), `.dataset` for xlsx/webp/mov

## Secrets pattern
`.gitignore` (2 lines): `VariableBlur/` and `MusicPlayer/APIKeys.swift`. APIKeys.swift is REQUIRED to compile but gitignored — shape: `enum APIKeys { static let openAI = "sk-..." }`. New project must recreate this file (or drop OpenAI usage).

## .claude settings
- /Users/dimazhuravlev/Repos/MusicPlayer/.claude/settings.json: `{"permissions":{"allow":["Bash(*)","Edit(*)","Write(*)","Glob(*)","Grep(*)","Read(*)"]}}`
- settings.local.json: allow `mcp__figma__get_design_context`, `WebFetch(domain:developers.deezer.com)`, `WebSearch`. For the new app, swap the WebFetch domain for the chosen public APIs (e.g. `api.kinopoisk.dev`, `openlibrary.org`, `api.deezer.com`, `itunes.apple.com`).

## RECOMMENDED SCAFFOLD PATH: copy pbxproj + sed rename (no Xcode GUI, no xcodegen/tuist)
Rationale: because of the synced-group format the pbxproj carries no file lists — a global rename is 100% safe (verified). xcodegen/tuist would add a toolchain dependency and can't trivially reproduce `objectVersion 77` synced groups; Xcode GUI not needed. Project name must be ASCII (e.g. `YandexPlus`); Russian display name goes into the quoted INFOPLIST key.

Exact verified steps (NAME=YandexPlus, DEST=/Users/dimazhuravlev/Repos/YandexPlus):
```bash
NAME=YandexPlus; SRC=/Users/dimazhuravlev/Repos/MusicPlayer; DEST=/Users/dimazhuravlev/Repos/$NAME
mkdir -p $DEST/$NAME.xcodeproj/project.xcworkspace/xcshareddata/swiftpm \
         $DEST/$NAME/Assets.xcassets/AppIcon.appiconset $DEST/$NAME/Assets.xcassets/AccentColor.colorset
# 1. pbxproj: global rename (also renames entitlements path and synced-group path)
sed "s/MusicPlayer/$NAME/g" $SRC/MusicPlayer.xcodeproj/project.pbxproj > $DEST/$NAME.xcodeproj/project.pbxproj
# 2. fix bundle id (sed produced com.dima.YandexPlus123) and display name
sed -i '' -e "s/com.dima.${NAME}123/com.dima.$NAME/" \
  -e "s/INFOPLIST_KEY_CFBundleDisplayName = Music;/INFOPLIST_KEY_CFBundleDisplayName = \"\\u042f\\u043d\\u0434\\u0435\\u043a\\u0441 \\u041f\\u043b\\u044e\\u0441\";/" \
  $DEST/$NAME.xcodeproj/project.pbxproj   # or just write 'INFOPLIST_KEY_CFBundleDisplayName = "Яндекс Плюс";' with an editor — pbxproj is UTF-8, literal Cyrillic in quotes works
# 3. workspace stub (required)
printf '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n' > $DEST/$NAME.xcodeproj/project.xcworkspace/contents.xcworkspacedata
# 4. root Info.plist (ATS), entitlements, pinned SPM state
cp $SRC/Info.plist $DEST/Info.plist
cp $SRC/MusicPlayer/MusicPlayer.entitlements $DEST/$NAME/$NAME.entitlements
cp $SRC/MusicPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved $DEST/$NAME.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/  # optional pin to c8dc0ad
# 5. minimal source: $DEST/$NAME/${NAME}App.swift with '@main struct ... App' (may 'import VariableBlur' immediately)
# 6. minimal Assets.xcassets: 3 Contents.json stubs (catalog root {"info":{"author":"xcode","version":1}}; AppIcon images:[{idiom:universal,platform:ios,size:1024x1024}]; AccentColor colors:[{idiom:universal}])
# 7. copy $SRC/.gitignore (edit APIKeys path), $SRC/.claude/, and Fonts/* + FontManager.swift pattern as needed; git init
```
Notes: no scheme files needed — xcodebuild auto-generates a scheme named after the target (verified: fresh copy with no xcuserdata listed scheme `SiblingTest`). Copied object UUIDs (FD67D4F4… etc.) are fine — uniqueness is per-project. If VariableBlur is unwanted, delete 5 blocks: PBXBuildFile line 10, the Frameworks entry line 30, packageProductDependencies 72-74, packageReferences 103-105, and sections XCRemoteSwiftPackageReference/XCSwiftPackageProductDependency (372-389).

## Verification command (verified working for both MusicPlayer and the scaffolded sibling)
```bash
cd $DEST && xcodebuild -project $NAME.xcodeproj -scheme $NAME \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```
Then install/launch on the already-booted sim: `xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/$NAME-*/Build/Products/Debug-iphonesimulator/$NAME.app && xcrun simctl launch booted com.dima.$NAME`.

## Gotchas
1. Deployment target 18.5 < sim runtime 26.x — fine; consider bumping to 26.0 if the new app wants Liquid Glass APIs (single sed of `IPHONEOS_DEPLOYMENT_TARGET = 18.5`).
2. `GENERATE_INFOPLIST_FILE = YES` + root `INFOPLIST_FILE = Info.plist` merge: add new plist keys (e.g. NSMicrophoneUsageDescription for Алиса mock) to root Info.plist, or as `INFOPLIST_KEY_*` build settings.
3. Display name with space/Cyrillic must be quoted in pbxproj.
4. Repo-root `VariableBlur/` folder is unreferenced scratch — do NOT copy it; the project pulls from GitHub.
5. First build resolves SPM from github.com; if pin matters copy Package.resolved (step 4), else you get latest `main`.

## REUSABLE
- Whole-pbxproj copy+rename works because of PBXFileSystemSynchronizedRootGroup (objectVersion 77): /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer.xcodeproj/project.pbxproj:17-23 — new source files need no project edits, just create on disk
- Runtime font registration without UIAppFonts: /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/FontManager.swift (CTFontManagerRegisterFontsForURL, called in MusicApp.init at MusicPlayer/MusicApp.swift:12) + typed Font extensions in MusicPlayer/Fonts/CustomFonts.swift
- Info.plist hybrid pattern: GENERATE_INFOPLIST_FILE=YES + minimal root Info.plist carrying only NSAppTransportSecurity/NSAllowsArbitraryLoads (/Users/dimazhuravlev/Repos/MusicPlayer/Info.plist)
- Entitlements minimal template: /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicPlayer.entitlements (only com.apple.security.network.client)
- Gitignored secrets file pattern: MusicPlayer/APIKeys.swift → enum APIKeys { static let openAI = "..." }, ignored via 2-line .gitignore
- Remote SPM dep template (VariableBlur, branch main): pbxproj sections at project.pbxproj:372-389 + productRef at line 10; pin via project.xcworkspace/xcshareddata/swiftpm/Package.resolved (rev c8dc0ad)
- .claude permissions template: /Users/dimazhuravlev/Repos/MusicPlayer/.claude/settings.json (Bash/Edit/Write/Glob/Grep/Read all-allow) + settings.local.json (WebFetch per-API-domain allowlist)
- Verified build/run loop: xcodebuild -project X.xcodeproj -scheme X -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build; then xcrun simctl install booted .../X.app && xcrun simctl launch booted com.dima.X (iPhone 17 Pro UDID 3DF755B7-31A1-48B9-8249-7002AF45AB80, already booted)

## OPEN QUESTIONS
- Keep iOS deployment target at 18.5 (as MusicPlayer) or bump to 26.0 to use Liquid Glass / newest SwiftUI APIs in the prototype?
- Preferred ASCII project name for "Яндекс Плюс" (YandexPlus? PlusApp? Superapp?) — determines folder, bundle id com.dima.<Name>, and scheme name
- Should the new app keep NSAllowsArbitraryLoads=true (guerrilla-style, any http API) or scope ATS exceptions to the chosen public API domains?
- Is VariableBlur needed from day one in the new app, or should the SPM sections be stripped from the copied pbxproj until required?
- Will the prototype reuse the OpenAI key / APIKeys.swift pattern (e.g. for Алиса responses), or is it fully offline-mock?