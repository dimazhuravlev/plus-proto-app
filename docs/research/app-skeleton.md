# MusicPlayer app skeleton analysis (for Яндекс Плюс superapp plan)

Repo: `/Users/dimazhuravlev/Repos/MusicPlayer`. Xcode project `MusicPlayer.xcodeproj`, target iOS 18.5, Swift 5.0, device family "1,2,7" (iPhone/iPad/Vision), local SPM package `VariableBlur/` (used for progressive-blur chrome backgrounds). All paths below relative to `MusicPlayer/MusicPlayer/`.

## 1. App entry + scene setup

- `MusicApp.swift:8-23` — `@main struct MusicApp: App`. `init()` does exactly two things: `FontManager.shared.registerFonts()` (custom fonts, `Fonts/FontManager.swift`) and `UIWindow.appearance().backgroundColor = .black` (guarded `#if canImport(UIKit)`). Single `WindowGroup { AppRootView() }`. No AppDelegate, no ScenePhase handling, no deep links.
- Imports at app level: UIKit (conditional), AVFoundation, CoreHaptics, SwiftUI (`MusicApp.swift:1-6`).

## 2. Root view hierarchy

Three-level structure:

1. **`AppRootView` (`MusicApp.swift:30-82`)** — the composition root. Owns ALL global state as `@StateObject` (lines 31-40) and injects each via `.environmentObject(...)` (lines 65-73). Body = `ZStack { Color.black.ignoresSafeArea(); MainContentView().background(.black).statusBar(hidden:false).preferredColorScheme(.dark) }`. Attaches `.toast(isPresented:$toastManager.isPresented, config:toastManager.currentConfig)` at root level (line 74) so toasts float above everything. `.task` (lines 75-80): `await curationManager.loadInitial()` → restore now-playing track via `Player.track(for:)` → `await curationManager.loadRemainingInBackground()` (two-phase content load: fast first paint, rest in background).
2. **`MainContentView` (`MusicApp.swift:104-914`)** — tab switcher + all fixed chrome layers + offline-flash transition orchestration (~700 lines, most of it the Metal offline-flash choreography, which is feature-specific and NOT part of the reusable skeleton).
3. **Screens** — each tab content lives in `Screens/` and is mounted inside per-tab `NavigationStack`s.

Custom `init()` in `AppRootView` (lines 42-53) builds `NowPlayingState` with `_nowPlayingState = StateObject(wrappedValue:)` because it needs a computed initial track.

## 3. Tab model + switching

- **`enum AppTab: Int, CaseIterable` (`MusicApp.swift:92-96`)**: `.showcase = 0, .collection = 1, .player = 2`. Held as `@State private var activeAppTab: AppTab = .showcase` in `MainContentView` (line 114) — NOT in an ObservableObject. Passed down to bottom bars as `@Binding var activeTab: AppTab` (`BottomBarV2.swift:10`, `BottomBar.swift:9`); bar buttons mutate the binding directly (`BottomBarV2.swift` tabBarRow: `activeTab = .showcase` / `.collection` + haptic).
- **No SwiftUI `TabView`.** Tab switching is a hand-rolled `switch activeAppTab` inside `Group` (`MusicApp.swift:185-255`):
  - `.showcase` → `NavigationStack(path: $showcaseNavigationPath)` wrapping a second-level hand-rolled sub-tab switch (`pendingTab` 0/1/2 → `ForYouShowcase`/`TrendsShowcase`/`ReligiousShowcase`, or `OfflineShowcase` when offline).
  - `.collection` → `NavigationStack(path: $collectionNavigationPath)` wrapping `Collection`.
  - `.player` → `Player(...)` full-bleed, `.ignoresSafeArea()`, NO NavigationStack.
- **Per-tab navigation persistence**: two `@State NavigationPath`s (`showcaseNavigationPath`, `collectionNavigationPath`, lines 120-121) so each tab keeps independent history; switching tabs unmounts the other stack but the path survives. NOTE: paths exist but screens actually navigate via boolean/item `navigationDestination` bindings (`ShowcaseFeedView.swift:68-76`, `TrendsShowcase.swift:120-129`, `ReligiousShowcase.swift:90`), not path pushes — the path is only used to force-reset (`showcaseNavigationPath = NavigationPath()`, `MusicApp.swift:681`).
- **Top sub-tab switching (showcase)**: `@State selectedTab: Int` (line 110) bound into `TopNavBar` (line 292); custom crossfade choreography via `isTransitioning`/`pendingTab`/`previousTab` + `DispatchQueue.asyncAfter` (lines 218-237): fade out 0.3s + blur(4) → swap content → fade in. Tabs default `["For You", "Trends", "Spiritual"]` (`TopNavBar.swift:29`); offline replaces with single `["Offline"]` title + toggle (`MusicApp.swift:284-289`).
- **Pop-to-root signal**: `ShowcaseNavState` (`MusicApp.swift:85-89`): `@Published isShowingDetail = false` + `@Published requestPopToRoot: Int` (increment-counter pattern). Detail screens set `isShowingDetail` in `.onAppear`/`.onDisappear` (`Screens/Album.swift:48-49`, `Playlist.swift:43-44`, `Artist.swift:41-42`, `Features/AlbumSkeletonScreen.swift:76-78`); feed listens `.onChange(of: requestPopToRoot)` and nils all its navigation booleans (`ShowcaseFeedView.swift:77-81`).

## 4. Fixed overlay layering (the key skeleton pattern)

`MainContentView.body` is one big `ZStack` (`MusicApp.swift:180-336`) + two `.overlay{}`s. Order bottom→top:

1. `Color.black.ignoresSafeArea()` (line 181)
2. Tab content `Group` (switch, lines 185-255)
3. `TopNavBarBackground()` — conditional, offline only (line 262-264)
4. `OfflineHeaderGlow()` — conditional, `.allowsHitTesting(false)`, asymmetric `.transition(.offset(y:-16).combined(with:.opacity))` (lines 268-277)
5. **Fixed top nav**: `VStack { TopNavBar(...); Spacer() }` — shown only when `activeAppTab == .showcase && !showcaseNavState.isShowingDetail` (lines 281-296). I.e. the GLOBAL top bar hides when a detail screen is pushed; detail screens render their own local nav bar with back button.
6. **Fixed bottom chrome**: `VStack { Spacer(); BottomBar | BottomBarV2 }.ignoresSafeArea(edges:.bottom)` (lines 299-318) — always mounted, in ALL tabs, floats above NavigationStack content so push/pop animations happen "under" it.
7. `ShareOverlay(entity:)` — `if let` from state, `.id(presentationID)`, `.transition(.opacity)`, `.zIndex(100)` (lines 321-326)
8. `OverflowMenu(entity:)` — same pattern, `.zIndex(101)` (lines 329-334)
9. `.overlay { OfflinePromptLayer }` — full-screen custom sheet ("Internet seems…"), driven by `offlineModeState.isSkeletonOfflineSheetPresented` (lines 337-351)
10. `.overlay { OfflineFlashOverlay }` — full-screen Metal shader transition (lines 352-368)
11. Toasts sit even higher — attached in `AppRootView` (line 74) via `.toast()` modifier; `Features/Toast.swift:76-96` `ToastManager.shared` singleton (`show(title:cover:coverURL:duration:4)`), `ToastPresenter` ViewModifier mounts `ToastView` in a ZStack over content, top-aligned, timer-token pattern to avoid stale auto-dismiss.

**BottomBarV2 internals** (`Features/BottomBarV2.swift`, the active v2 chrome; Figma ref "Tabbar • New Navigation", 375pt): `GeometryReader` → `ZStack(alignment:.bottom)`:
- `chromeBackground()` — `VariableBlurView(maxBlurRadius:12, direction:.blurredBottomClearTop)` height 120 + gradient, `.allowsHitTesting(false)`, hidden on `.player` tab (line ~256)
- `tabBarRow` — 3 buttons (Discover / Search-placeholder / My Collection), padding bottom `safeBottom + 38`
- `MiniPlayerV2(track:)` (line 298) — **the mini player LIVES INSIDE BottomBarV2**, positioned ABOVE the tab row: bottom inset 80pt online / 60pt offline (`figmaMiniBottomInsetOnline/Offline`), horizontal padding 24, bar height 56 (`miniPlayerBarHeight`)
- offline caption + pull-to-offline hint layers.
- Numerous per-layer `.animation(_, value:)` modifiers; explicit `.animation(nil, value: activeTab)` on mini player to prevent unwanted interpolation on tab switch.
- Legacy `BottomBar` (`Features/BottomBar.swift`) kept behind `@AppStorage("debug_legacy_bottom_bar")` flag (`MusicApp.swift:143-146`, toggled in `Wizard.swift:6`); it contains the `keyWindow`/`pinOffset` trick (BottomBar.swift:27-44) to pin the bar to the true window bottom because GeometryReader heights differ between full-bleed Player and NavigationStack tabs.

**Modal sheets** are NOT global: `.fullScreenCover` for Wizard lives on TopNavBar's userpic button (`TopNavBar.swift:128`), debug sheet on Wizard (`Wizard.swift:198` via `DebugPanelState`), track sheets local to lists (`TrackListView.swift:34`, `TrackCarouselView.swift:36`).

## 5. State objects — full inventory

All are plain `final class X: ObservableObject` (no @Observable macro anywhere). Injection: created once in `AppRootView` as `@StateObject`, distributed via `.environmentObject`; consumed via `@EnvironmentObject`. Four are singletons additionally reachable via `.shared`:

| Object | File | Singleton? | Injected? | Purpose / key @Published |
|---|---|---|---|---|
| `ToastManager` | Features/Toast.swift:76 | `.shared`, private init | no (bound at root via `.toast()`) | `isPresented`, `currentConfig`; `show()` callable from anywhere |
| `GyroManager` | Features/GyroManager.swift:5 | `.shared`, private init | yes | `roll/pitch/yaw/basePitch/baseRoll` clamped ±0.6, 60Hz CMMotionManager; comment: multiple CMMotionManagers break device updates → must be one instance. Simulator fallback: CADisplayLink demo sine tilt (`isUsingSimulatorDemo`). Powers `Gyro3DTilt` parallax |
| `DebugPanelState` | MusicApp.swift:26-28 | no | yes | `isPresented` for debug sheet |
| `ShowcaseNavState` | MusicApp.swift:85-89 | no | yes | `isShowingDetail`, `requestPopToRoot` counter |
| `ShareOverlayState` | Data/ShareOverlayState.swift | no | yes | `presentedShareEntity: ShareableEntity?`, `presentationID: UUID` (regenerated per `present()` so SwiftUI never reuses stale view state); `pendingRemovalWork: DispatchWorkItem` cancellation — comment says without it, a 2nd present leaves an invisible touch-blocking layer |
| `OverflowMenuState` | Data/OverflowMenuState.swift | no | yes | identical clone of ShareOverlayState for long-press menu |
| `NowPlayingState` | Data/NowPlayingState.swift | no | yes | `@MainActor`; `track: Track` (didSet → persist + play), `isPlaying` (didSet → sync to `AudioPlayerManager.shared` with `isSyncing` reentrancy guard), `trackIndex: GridIndex?`; Combine sink on `audioPlayer.$isActuallyPlaying`; persists last track to UserDefaults keys `np_*` for cold-start mini player cover |
| `CollectionState` | Features/CollectionState.swift | no | yes | last two liked covers (`previousCover(_URL)`, `latestCover(_URL)`), `registerLike()`, persisted to UserDefaults `collection_*` |
| `OfflineModeState` | Data/OfflineModeState.swift | no | yes | pure state bag, no logic: `isEnabled`, `downloadsPullChromeProgress: CGFloat` (0…1 interactive pull), `collectionTopTabIndex`, `offlineTransitionChromeFloor: CGFloat?`, `headerGlowOpacity`, `preferredCollectionTopTab: Int?`, `isSkeletonOfflineSheetPresented` |
| `ContentCurationManager` | Services/ContentCurationManager.swift:5-6 | `.shared` | yes | curated content feed; `loadInitial()` / `loadRemainingInBackground()` / `loadMyVibeGeneratorTracksIfNeeded()` |
| `AudioPlayerManager` | Services/AudioPlayerManager.swift | `.shared` | no (accessed via NowPlayingState.audioPlayer) | actual AVAudio playback, `$isActuallyPlaying` |
| `ShaderPlayerManager` | (Glow Button) | no | no — `@StateObject` in MainContentView:115, passed by param to showcases | Metal shader anim state shared between showcase generators |

Pattern note: singleton + `@StateObject(wrappedValue: X.shared)` dual access = imperative calls from anywhere (`ToastManager.shared.show(...)`) AND reactive SwiftUI observation.

## 6. Lifecycle / misc

- Everything dark-mode-only: `.preferredColorScheme(.dark)` + black window + black backgrounds per NavigationStack root.
- `.onChange(of: activeAppTab)` (MusicApp.swift:410-425): dismisses offline sheet, resets pull progress with `Transaction(animation:nil)`, one-time player grid-index restore (`didRestorePlayerGridIndex`).
- `.onChange(of: offlineModeState.isEnabled)` (369-409): the cross-cutting mode transition entry point.
- Heavy use of `Transaction`/`withTransaction(animation:nil)` to mutate state without implicit animation; `withAnimation(.smooth(duration:))` for choreography; async `Task { @MainActor in ... Task.sleep ... }` sequenced timelines with an **epoch counter** (`offlineFlashEpoch: UInt64`, line 138) so cancelled tasks waking from sleep can't clobber a newer transition (comment at 908-912); `performDeferredOfflineNavigationRedirect` (571-583) defers heavy tab/root swaps to the next run-loop pass to avoid a frame hitch mid-shader-animation.
- `#Preview` at MusicApp.swift:916-925 re-injects fresh environment objects manually — every env-consuming view needs this.

## 7. Assessment: changes needed for 5-tab superapp (Плюс/Музыка/Кинопоиск/Книги/Алиса) with persistent tabbar + action bar (search/miniplayer) above it

**Keeps as-is (proven patterns):**
- `WindowGroup → AppRootView (state owner + env injection + .toast) → MainContentView (ZStack: content switch + fixed chrome + zIndexed overlays)` — directly reusable.
- Hand-rolled tab switch instead of TabView — required anyway for a custom persistent tabbar + fully custom chrome animations.
- Per-tab `NavigationPath` array, overlay-state pattern (`presentationID` + pending-removal-work), ToastManager, VariableBlur chrome background, Transaction-based no-animation mutations, epoch-guarded async choreography.

**Required changes:**
1. **`AppTab` → 5 cases** (`plus, music, kinopoisk, books, alisa`), each needing metadata (title, icon asset, selected icon) — worth a computed props extension since BottomBarV2 currently hardcodes its 3 buttons inline (`tabBarRow`, BottomBarV2.swift:~350-395). Rebuild `tabBarRow` as `ForEach(AppTab.allCases)`.
2. **NavigationPath per tab: 2 → 4-5** `@State` paths (Алиса likely modal/overlay rather than a stack — decide). Consider moving paths + activeTab into a `NavigationState: ObservableObject` instead of `@State` in MainContentView: with 5 tabs, cross-tab deep links ("open this film from Алиса answer") need external mutation access, which the current `@State`-in-view design blocks (today only reachable because all the transition code lives inside the same 700-line view — a structure to avoid repeating).
3. **Two-row bottom chrome.** Today mini player and tabbar are both inside BottomBarV2 at fixed insets (80/38pt). Superapp spec = persistent tabbar + separate action bar (search + miniplayer) above it. Restructure into `SuperBottomChrome`: `VStack(spacing:) { ActionBar(search, MiniPlayerV2-style capsule); TabBarRow(5 items) }` inside the same GeometryReader/ZStack(alignment:.bottom) + single VariableBlur `chromeBackground()`. Mini player presence becomes conditional/animated (music playing state), so the action bar needs a collapsed (search-only) ↔ expanded (search+mini) layout animation — new logic, but BottomBarV2's progress-driven offset/opacity/blur approach (`offlineChromeProgress`-style 0…1 drivers) is exactly the right template.
4. **Global top nav is showcase-only today** (condition `activeAppTab == .showcase` at MusicApp.swift:281). Each superapp tab will want its own header → either replicate `isShowingDetail`-style hide logic per tab, or (simpler) drop the global TopNavBar and let each tab own its header inside its NavigationStack, keeping only the global bottom chrome + overlays fixed. Keep `ShowcaseNavState`-style `isShowingDetail` if bottom chrome must react to detail screens (e.g. hide action bar on a film page).
5. **NowPlayingState generalization**: today it's music-only and drives `MiniPlayerV2(track:)` directly. For a superapp mini player that may surface a film-continue-watching or audiobook, either keep NowPlayingState music-only and add a parallel `ContinueWatchingState`/`PlaybackHub`, or introduce an enum payload (`NowPlayingItem { case track(Track), case audiobook(...), ... }`). Books+Music both being audio suggests a shared audio hub; Кинопоиск stays visual-only.
6. **Per-service state objects**: replicate the pattern — one small ObservableObject per domain (e.g. `KinopoiskState`, `BooksState`, `AlisaState` mock/session state), all created in AppRootView, all injected. Keep `OfflineModeState`-style "pure state bag, logic lives in the orchestrating view" separation.
7. **Extract transition choreography out of MainContentView.** ~600 of its 810 lines are the offline-flash feature. For the superapp, per-tab entrance transitions (if any) should live in dedicated helper types/modifiers, keeping MainContentView to ~150 lines: switch + chrome + overlays + onChange hooks.
8. **Алиса as overlay vs tab**: existing full-screen `Yasmina/YasminaFlow` (fullScreenCover from `Wizard.swift:204`) is a ready-made assistant-flow precedent (staged flow model `YasminaFlowModel`, haptics, tokens) — likely the closest reusable base for the Алиса tab/overlay.
9. **Data layer**: `Services/DeezerService.swift` + `Data/DeezerModels.swift` + `CachedAsyncImage` + `ContentCurationManager` two-phase load is the template for Кинопоисk (e.g. TMDB/Kinopoisk API mock) and Books (e.g. Google Books/OpenLibrary) services: each new service = `XService` (fetch) + `XModels` + curation manager with `loadInitial()/loadRemainingInBackground()`.
10. Untouched infra ready to reuse: `FontManager` registration, Colors.swift tokens (`.fill1`, `.subtitle`), haptic helpers, `Gyro3DTilt`, Shimmer/skeleton screens, `ShareableEntity` + share/overflow overlays (extend `ShareableEntity` enum with film/book cases).

**Risks/gotchas to carry into the plan:**
- The classic BottomBar's window-pinning hack (BottomBar.swift:27-44) exists because full-bleed screens vs NavigationStack screens give the chrome's GeometryReader different heights — if any superapp tab is full-bleed without a NavigationStack (like Player today), the same vertical-jump bug will appear; either give every tab a NavigationStack or port the pinOffset fix into the new chrome.
- `.animation(nil, value: activeTab)` on the mini player (BottomBarV2.swift:~308 comment) — without it, tab switches drag the mini player through a ~420ms arc; must be preserved in the new action bar.
- ShareOverlay/OverflowMenu zIndex constants (100/101) — new global overlays (Алиса voice sheet?) need slots above/below deliberately.
- Preview blocks must manually inject every environmentObject; 10+ objects → make an `.injectAppEnvironment(mock:)` helper early.

## REUSABLE
- Composition root pattern: AppRootView owns all @StateObjects, injects via .environmentObject, attaches .toast at root — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicApp.swift:30-82
- ZStack chrome layering (content switch → fixed top nav → fixed bottom chrome ignoresSafeArea(.bottom) → zIndexed global overlays 100/101 → .overlay sheets) — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicApp.swift:179-368
- AppTab enum + @State activeAppTab + @Binding into bottom bar, no TabView — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicApp.swift:92-96,110-121,185-255
- Per-tab NavigationStack(path:) with independent @State NavigationPath + counter-based requestPopToRoot reset — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicApp.swift:85-89,120-121,676-682 and Screens/ShowcaseFeedView.swift:68-81
- Bottom chrome with VariableBlur background + progress-driven (0…1) offset/opacity/blur choreography + mini player at fixed Figma insets — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift (MiniPlayerV2 mount at :298, chromeBackground VariableBlurView maxBlurRadius:12 height:120)
- Global overlay state pattern (presentationID UUID per present + DispatchWorkItem pending-removal cancellation) — Data/ShareOverlayState.swift and Data/OverflowMenuState.swift (identical clones; third copy = extract generic)
- ToastManager singleton + .toast ViewModifier with timer-token stale-dismiss guard — /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/Toast.swift:76-101,209-224
- NowPlayingState: @MainActor ObservableObject, didSet persistence to UserDefaults, isSyncing reentrancy guard, Combine bridge to AudioPlayerManager.shared — Data/NowPlayingState.swift
- Pure state-bag ObservableObject (no logic, orchestration in view) — Data/OfflineModeState.swift
- GyroManager: enforced-singleton CMMotionManager 60Hz with simulator CADisplayLink demo fallback, clamp ±0.6 — Features/GyroManager.swift (+ consumer Features/Gyro3DTilt.swift)
- Epoch-counter (UInt64) cancellation guard for Task.sleep choreography + withTransaction(animation:nil) mutations + deferred run-loop redirect — MusicApp.swift:137-138,571-583,908-913
- Two-phase content load: loadInitial() then loadRemainingInBackground() in root .task — MusicApp.swift:75-80, Services/ContentCurationManager.swift
- Service template for new APIs: Services/DeezerService.swift + Data/DeezerModels.swift + Features/CachedAsyncImage.swift
- Assistant-flow precedent for Алиса: Yasmina/ full-screen staged flow (YasminaFlow, YasminaFlowModel, YasminaHaptics, YasminaTokens)
- Debug chrome toggle via @AppStorage("debug_legacy_bottom_bar") + DebugPanelState sheet — MusicApp.swift:142-146, Screens/Wizard.swift:6,198
- Window-bottom pinning fix for mixed full-bleed/NavigationStack tabs — Features/BottomBar.swift:27-44 (pinOffset via keyWindow height)

## OPEN QUESTIONS
- Is Алиса a real 5th tab with its own NavigationStack, or a global overlay/fullScreenCover (like Yasmina today) summoned from the action bar?
- Action bar composition: is search a field, a button, or a tab-like entry? Does the mini player collapse the action bar to search-only when nothing is playing, and what plays there for Кинопоиск/Книги (continue-watching card, audiobook)?
- Should the mini player state be unified across Музыка and Книги (audiobooks) into one playback hub, or stay music-only?
- Does the persistent tabbar hide/shrink on detail screens (film page, book reader, full player), or stay visible everywhere like BottomBarV2 does today?
- Is there a global top nav shared across tabs (like TopNavBar on showcase), or does each tab own its header — and does Плюс home need the sub-tab crossfade pattern (For You/Trends-style)?
- Cross-tab deep links (e.g. Алиса answer opens a film in Кинопоисk): required for the prototype? This decides whether activeTab/NavigationPaths move from @State into an injectable NavigationState object.
- Which free public APIs are targeted per vertical (TMDB vs kinopoisk.dev for films; OpenLibrary vs Google Books; keep Deezer for music?) and is offline mode / the Metal flash transition carried over at all?
- Dark-only like MusicPlayer, or does Плюс branding need light mode support?