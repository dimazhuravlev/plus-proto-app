# Navigation & Player Chrome — MusicPlayer analysis (for Яндекс Плюс plan)

All paths relative to `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/`.
External dep: `VariableBlur` SPM package, github.com/nikstar/VariableBlur, pinned to **branch main** (project.pbxproj:373-380). API used: `VariableBlurView(maxBlurRadius:direction:[startOffset:])`, directions `.blurredBottomClearTop` / `.blurredTopClearBottom`.

## 1. App shell / tab model (MusicApp.swift)

- `enum AppTab: Int { showcase=0, collection=1, player=2 }` — MusicApp.swift:92-96. Single source of truth `@State activeAppTab` in `MainContentView` (line 114), passed as `Binding<AppTab>` into bars.
- Root layering (MusicApp.swift:179-335): ZStack = [black bg → `switch activeAppTab` content (each tab own `NavigationStack` + own `NavigationPath`, lines 120-121, 188/242) → TopNavBar pinned via `VStack{bar;Spacer()}` (281-296) → bottom bar pinned via `VStack{Spacer();bar}.ignoresSafeArea(.bottom)` (299-318) → overlays with `.zIndex(100/101)`].
- Tab CONTENT switch is a hard `switch` (no crossfade between tabs at root; bar highlights animate, content swaps instantly). Sub-tab (top nav) switching inside showcase is a manual two-phase fade: phase 1 fade-out `isTransitioning=true` with `.smooth(0.3)` + `blur(radius: 4)`, after `asyncAfter(0.3)` swap `pendingTab`, after `+0.005` fade back in (MusicApp.swift:196-237).
- Bar style feature-flag: `@AppStorage("debug_legacy_bottom_bar")` → `BottomBarStyle .classic | .v2` (MusicApp.swift:98-102, 142-146) — good pattern for prototyping two chrome generations.

## 2. BottomBar (classic, Features/BottomBar.swift)

Layout: HStack of 3 hit targets each `.frame(72×72)` (`tabContainerSize`, line 13), `.padding(.horizontal, 48)`, `.padding(.bottom, 26)` from window bottom (lines 129-132).
- Left: `MiniPlayer` (circular cover) — tap: if already `.player` tab, jump `playerGridIndex` to now-playing; else `withAnimation(.smooth(0.3)) activeTab = .player` (48-65).
- Middle: `ShaderButtonView()` 80×80 — Metal shader glow blob (Glow Button/ShaderButtonView.swift, UIViewRepresentable over MTKView-like view w/ uniforms: interaction, reactTop/Middle/Bottom, audio4/5, sparkStrength, scale). Tap → showcase tab.
- Right: `CollectionTabCovers` — two angled 48×48 album covers (cornerRadius 8, stroke `Color.fill1` 2pt).

Key mechanics:
- **Window-pinning hack** (lines 26-42): geometry differs per tab (Player is full-bleed `.ignoresSafeArea` → GeometryReader gets taller). Fix: `pinOffset = keyWindow.bounds.height − geo.frame(in:.global).maxY`, applied as `.offset(y: pinOffset)` so the row never jumps between tabs. Reuse this if the new app mixes full-bleed and safe-area screens.
- **Frosted background** (146-181): shown only when `activeTab != .player`; `ZStack{ VariableBlurView(maxBlurRadius: 8, .blurredBottomClearTop).frame(height:100) + 16-stop black LinearGradient 0→0.8 opacity top→bottom, height 100 }`, removal/insert `.transition(.opacity)`.
- Press states: `DragGesture(minimumDistance: 0).simultaneousGesture` pattern — onChanged→pressed=true, onEnded→false; scale 0.92 with `.smooth(0.15)` (showcase btn) / `.smooth(0.2)` (covers), miniplayer 0.95 `.smooth(0.12)`.
- Haptic on tab switch: `UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)` (185-188).

`CollectionTabCovers` "new like added" animation (lines 205-393) — a polished 3-card shuffle worth copying:
- resting transforms: left (rot −10°, x −10, y 4), right (rot +10°, x 12, y −2); pressed: (−14, −14, 4)/(14, 16, −2) (line 331-342).
- new cover enters from y −40, rotation +24° over resting, opacity 0→1; outgoing right card slides to left slot; old left fades out. Spring `.spring(response: 0.5, dampingFraction: 0.8)`; incoming delayed 0.05×1.4s; global `animationSlowdown = 1.4`; base durations transition 0.35/press 0.15/fade 0.2. Final state swap wrapped in `Transaction{disablesAnimations=true}` to avoid flash (373-390).

## 3. BottomBarV2 (Features/BottomBarV2.swift) — current production style

Structure (body 254-347): GeometryReader → ZStack(alignment:.bottom) = [chromeBackground (only if `activeTab != .player`, `allowsHitTesting(false)`) → tabBarRow → offline caption → MiniPlayerV2 → pull-glow layer], all `.ignoresSafeArea()`.
- **tabBarRow** (349-392): 3 `tabButton`s in HStack(spacing:0), each `Image` 32×32 template, selected asset swap (`music-fill`↔`music`, `like-default`↔`like-fill`), color `Color.fill1` selected / `Color.subtitle` unselected, `.animation(nil, value: iconAsset)` (icon swap NOT animated — deliberate), press scale 0.92 `.smooth(0.15)`. Hit area: `.frame(maxWidth:.infinity).padding(.h,4).padding(.v,8).contentShape(Rectangle())`, `Button(.plain)`. Row paddings: horizontal 40, top 16, bottom 24; row layout height const `16+32+16+24` (line 168). Bottom inset from safe area: 38 (`figmaTabsBottomInset`, line 128).
- Selected-state mapping: `discoverSelected = activeTab == .showcase || .player` (28-30) — the player counts as "Discover" tab.
- Tab switch animation on the row: `.animation(.smooth(duration: 0.42), value: activeTab)` (line 281).
- **chromeBackground** (394-418): `VariableBlurView(maxBlurRadius: 12, .blurredBottomClearTop)` height 120 (`chromeBottomMaterialHeight`, line 162) + subtle LinearGradient stops [clear@0, black 0.12@0.5, black 0.06@0.82, clear@1].
- **Mini player position**: `MiniPlayerV2` sits ABOVE the tab row — `.padding(.horizontal, 24)`, bottom = `safeBottom + 80` online (interpolates to 60 in offline mode) (125-126, 178-183). This "pill above tab row" = exactly the requested "action bar above tabbar" slot.
- **Offline chrome choreography** (the morph reference): a single scalar `offlineChromeProgress` 0…1 (47-73) drives: tab row slides down `figmaTabsSlideDown = 56`pt + fades out linearly over first 0.5 of progress (`tabBarFadeOutProgressEnd`) + blur up to `tabBarDismissBlurMax = 5` + row layout height collapses after fade (221-236); mini bottom inset lerps 80→60 with mini progress boosted ×1.18 (`miniChromeProgressBoost`, 143); caption fades in. Interactive (follows finger via `downloadsPullChromeProgress`) with `.animation(nil)`; programmatic (flash) with `.smooth(1.0)` enter / `.smooth(0.089)` pull-follow / `.smooth(0.13)` mini (132-134, 238-252). Entrance after redirect: chrome starts +32pt down / opacity 0 → rises with `.smooth(0.13)` default (`offlineShowcaseChromeEntranceOffset = 32`, line 149).
- Note line 307: `.animation(nil, value: activeTab)` on MiniPlayerV2 — kills unwanted arc interpolation when ZStack-level `.animation(value: activeTab)` would drag the mini through Showcase→Collection layout change. Important gotcha for a morphing action bar.
- Same medium/0.7 haptic on tab tap (466-469).

## 4. MiniPlayer (classic circular, Features/MiniPlayer.swift)

- 56×56 circular cover in 68×68 hit frame, progress ring: bg `Circle().stroke(white 0.1, 2pt)` + `Circle().trim(0→audioPlayer.progress).stroke(white, 2pt round cap)`, both `.rotationEffect(-90°)`, 58×58 (20-45).
- Vinyl rotation: `TimelineView(.animation)` manual integration — `targetSpeed = 40°/s`; ease via `currentSpeed += (target − currentSpeed) * 0.04` per frame (spin-down on pause); on play-start jumps straight to full speed (47-64).
- Play-start haptic: CoreHaptics `CHHapticEngine`, one `.hapticContinuous` event: intensity 0.40, sharpness 0.30, attackTime 0.50, decayTime 0.30, releaseTime 0.60, sustained 1, duration 0.50s (125-151). Engine restart handler for audioSessionInterrupt/applicationSuspended (105-123).
- Cover change: fade out `.smooth(0.3)` → after 0.1s swap asset → fade in `.smooth(0.3)` (66-77).
- Press: scale 0.95, `.smooth(0.12/0.15)`.

## 5. MiniPlayerV2 (Features/MiniPlayerV2.swift) — pill bar, DIRECT template for the action bar

- Fixed `barHeight = 56`, `cornerRadius = 100` continuous (full capsule), cover 48 (13-16).
- Layer stack (21-32): base fill `Color(r20 g20 b20).opacity(0.72)` → `.ultraThinMaterial` → progress fill `white.opacity(0.06)` with width `w * progress`, animated `.easeOut(0.12)` per tick → content HStack.
- Content: rotating circular cover (TimelineView, constant `18°/s`, no easing, 8-48) + title/artist `VStack(spacing:2)` `.font(.Text2)` colors `.fill1`/`.subtitle` + trailing actions HStack(spacing:18) of 24×24 template icons (`like-default`, `pause`). Paddings: leading 6, trailing 18, vertical 6 (80-82).
- Border: `stroke(white.opacity(0.08), lineWidth: 0.66)` — the 0.66pt hairline + white 0.08-0.1 stroke is the recurring chrome idiom app-wide.
- Currently **visual-only**: `.onTapGesture { }` absorbs taps (92-93).

## 6. TopNavBar (Features/TopNavBar.swift)

- Text-tabs header ("For You/Trends/Spiritual"): selected `.fill1`, unselected `white.opacity(0.35)`, color anim `.smooth(0.4)`; press scale 0.9 `.smooth(0.1)` (62-68).
- **Moving dot indicator** (92-105): 8×8 `Circle().fill(.fill1)` + shadow(black 0.3, r4), x computed from tab width `(width − (n−1)*10)/n`, positioned y=48, spring `.spring(response: 0.6, dampingFraction: 0.75)` — nice reusable "active tab indicator" spring.
- Haptic on top tab change: `.light` impact, only when index actually changed (70-75, 154-158).
- `TopNavBarBackground` (164-204): 16-stop black gradient 0.75→0 height 130 + TWO stacked `VariableBlurView(.blurredTopClearBottom)`: radius 4 @ height 140 and radius 14 @ height 100; self-anchors to physical top via `VStack+Spacer+.ignoresSafeArea(.top)`, `allowsHitTesting(false)`. Split out as separate view so a glow layer can be sandwiched between bg and content (see MusicApp.swift:262-277 z-ordering comment).

## 7. NavBar (detail screens, Features/NavBar.swift)

- Scroll-linked: `ScrollOffsetPreferenceKey` + `.trackScrollOffset(in:offset:)` extension (5-31, 243-247). Content (mini cover + title) appears at `scrollOffset >= 360` hard threshold with `.easeInOut(0.4)`; background fades `min(1, (offset−200)/80)` with `.easeOut(0.2)` (81-89, 167-168).
- Background: `VariableBlurView(maxBlurRadius: 16, .blurredTopClearBottom)` h105 + same 16-stop black gradient h120.
- Circle buttons (Back/Search): 40×40, `.ultraThinMaterial.opacity(0.5)` bg, hairline stroke white 0.1 / 0.66pt (174-214); `SkipButton` capsule same recipe.

## 8. PlayPauseButton + AnimatedIconButton

- `PlayPauseButton` (Features/PlayPauseButton.swift): Circle `white.opacity(0.1)`, default size 64, icon = size×0.5. On tap: bg scale →0.8 then back to 1.0 after 0.1s, spring `.spring(response: 0.3, dampingFraction: 0.8)`; haptic `.light` intensity 1.0.
- `AnimatedIconButton` (Features/AnimatedIconButton.swift): two overlaid template Images cross-morph; inactive icon opacity 0 / scale 0.4, active opacity 1 / scale 1; all three `.animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.5))` on `isActive`, `iconScale`, `iconOpacity`. Tap choreography: manually set opacity 0 + scale 0.4 → `asyncAfter(0.1)` → call `onTap()` (flips isActive) + restore 1.0 (58-67). Haptics hardcoded by asset-name pairs (play/pause, like) — refactor target: pass a flag instead (52-56).

## 9. Player 2D pager (Screens/Player.swift) — gesture system

Contract (7-14): every slide exactly `UIScreen.main.bounds` size; container same size `.clipped()`; slide strip = current slide (offset = dragOffset projected to locked axis) + one neighbor at ±screenW/H; commit slides full span then state resets without animation.
- Constants: `commitDuration = 0.3`, `lockThreshold = 8`pt (39-40).
- **Axis lock** (270-282): first drag frame where `max(|dx|,|dy|) > 8` → `lockedAxis = |dx|>|dy| ? .horizontal : .vertical`; offset then projected to that axis only (`currentSlideOffset`, 131-136).
- **Rubber-band**: if no neighbor exists in drag direction → `adjusted = primary * 0.25` (line 286).
- Neighbor mounted lazily with direction; `neighborOffset = dragOffset ± screen span` (139-146).
- **Commit rule** (300-319): threshold `span * 0.2` on either actual translation OR `predictedEndTranslation` (velocity-aware); animate `dragOffset` to ±span with `.easeInOut(0.3)`; after `commitDuration + 0.02` do the swap (`current = next`, zero offsets, clear axis/neighbor) inside `Transaction{disablesAnimations = true}` (331-345).
- Swipe-commit haptic: `.soft` impact intensity 0.8 (464-468).
- Gesture attached via `.simultaneousGesture(makeDragGesture())` on the container so cover tap/long-press still work; cover press state force-released when axis locks (81-87).
- **External index change** (tap from another screen): crossfade path `startCrossfade` — outgoing slide kept, `crossfadeProgress` 0→1 `.easeInOut(0.35)` (470-477).
- **Auto-advance** on track end (399-434): programmatic swipe left — sets `lockedAxis`/`neighborSlide` manually BEFORE animating dragOffset to −screenW with same `.easeInOut(0.3)`.
- Infinite grid content: deterministic pseudo-random track per `GridIndex` via seeded RNG `(x*73856093 ^ y*19349663) ^ randomSalt` + static cache (509-522); preloads 4 neighbors' images + dominant colors on index change (480-495).
- Slide bg: mirrored artist photo (bottom half `scaleEffect(x:1,y:−1)`), `VariableBlurView(maxBlurRadius: 50, .blurredBottomClearTop, startOffset: 0.4)`, dominant-color gradient opacity 0.2, grain overlay (195-240). Dominant colors animated in `.easeInOut(0.4)`.
- Fact overlay pinned `padding(.bottom, 136)` above the bar; fade in `.easeIn(0.3)` / out `.easeOut(0.15)`.

## 10. Complete animation-value table

| What | Value |
|---|---|
| Tab switch (bar → activeTab) | `.smooth(0.3)` (classic), `.smooth(0.42)` row anim (V2) |
| Press-down scale (icons/buttons) | 0.9-0.95 scale, `.smooth(0.1…0.2)` (most: 0.15) |
| Top tab text color | `.smooth(0.4)` |
| Top dot indicator | `.spring(response:0.6, dampingFraction:0.75)` |
| Icon morph (play↔pause etc.) | `.spring(response:0.3, dampingFraction:0.6, blendDuration:0.5)`, hide state scale 0.4 |
| PlayPause bg pulse | scale 0.8 for 0.1s, `.spring(0.3, 0.8)` |
| Pager commit / auto-advance | `.easeInOut(0.3)` + cleanup at +0.02s, disablesAnimations |
| Pager crossfade (external jump) | `.easeInOut(0.35)` |
| Cover swap fade (mini) | out `.smooth(0.3)` → 0.1s → in `.smooth(0.3)` |
| Mini progress fill (V2) | `.easeOut(0.12)` |
| Vinyl spin | 40°/s (classic, lerp 0.04/frame decel) / 18°/s (V2 constant) |
| Cards shuffle (collection tab) | `.spring(0.5, 0.8)`, delays ×1.4 slowdown, enter from y−40/rot+24° |
| NavBar bg fade | `(offset−200)/80`, `.easeOut(0.2)`; content at ≥360, `.easeInOut(0.4)` |
| Offline chrome slide | interactive: none; flash enter: `.smooth(1.0)`; follow: `.smooth(0.089)`; mini: `.smooth(0.13)`; entrance rise 32pt |
| Showcase sub-tab content swap | fade+blur(4) out 0.3s → swap → in (asyncAfter 0.3 + 0.005) |

## 11. Haptics table

| Trigger | API / params |
|---|---|
| Bottom tab tap | `UIImpactFeedbackGenerator(.medium)`, intensity 0.7 (BottomBar.swift:185-188, BottomBarV2.swift:466-469) |
| Top tab change | `.light` default intensity (TopNavBar.swift:154-158) |
| Play/pause, like icon | `.light`, intensity 1.0 (AnimatedIconButton.swift:52-56, PlayPauseButton.swift:48-49) |
| Pager swipe commit | `.soft`, intensity 0.8 (Player.swift:464-468) |
| Play start (mini) | CoreHaptics continuous: int 0.40, sharp 0.30, attack 0.50, decay 0.30, release 0.60, sustained, 0.50s (MiniPlayer.swift:125-151) |
| Cover long-press → menu | `.medium` (Player.swift:436-439) |
| Offline flash | CoreHaptics transient "roulette": first gap 0.054s, gapGrowth ×1.152, intensity 0.68 decaying `exp(−k*0.048)` clamp 0.38…0.95, sharpness 0.6 (MusicApp.swift:481-540) |

## 12. Mapping to new app requirements

**5-tab tabbar with animated active state** — base on `BottomBarV2.tabBarRow` (BottomBarV2.swift:349-392): change HStack to 5 `tabButton`s (already `maxWidth:.infinity` equal distribution; hit areas grow/shrink automatically). Active-state anim options already in codebase: (a) filled/outline asset swap w/ `.animation(nil)` (V2 current), (b) `AnimatedIconButton` spring cross-morph for a livelier active state, (c) TopNavBar dot-indicator spring for a moving underline/dot. Keep press-scale 0.92 `.smooth(0.15)` + medium/0.7 haptic. Keep `chromeBackground` recipe (VariableBlur 12 / h120 + faint gradient) and the `activeTab != .player`-style suppression for full-bleed screens.

**Action bar morphing between 4 states (search / music / book / movie player)** — this exact component does NOT exist; closest scaffolding:
- Slot & geometry: MiniPlayerV2 pill (h56, capsule, `.ultraThinMaterial` over 0.72 dark fill, hairline 0.66/white-0.08 stroke) at `safeBottom + 80`, horizontal padding 24 — already positioned "above tabbar" (BottomBarV2.swift:298-316).
- Morph driver precedent: `offlineChromeProgress` scalar-driven multi-property choreography (BottomBarV2.swift:47-73 + 172-252) shows the house style: one 0…1 progress, per-element lerps (offset/opacity/blur/height), separate boost multipliers (×1.18), explicit `.animation(nil, value:)` guards against cross-contamination. For 4 discrete states use matchedGeometry or fixed-height pill whose CONTENT crossfades (cover-swap pattern MiniPlayer.swift:66-77) — none of this is prebuilt; must be designed.
- In-bar progress fill (MiniPlayerV2.swift:28-31) works for music/book audio states; icon morphs from AnimatedIconButton.
- Search state: `SearchButton`/capsule recipes in NavBar.swift:193-240 give the material/stroke language.

**Player screens** — Player.swift's 2D pager is directly liftable for the movie/music vertical feed (axis-lock, 0.2-span commit w/ predicted translation, 0.25 rubber-band, `Transaction` cleanup). GridIndex can become 1D (y only) trivially by returning nil direction for the dead axis (`directionFor`, 457-462 + `neighborIndex`, 351-360).

**Known gotchas to carry over**
- Bottom-bar window pinning across full-bleed vs NavigationStack tabs (BottomBar.swift:23-42) — or ensure all 5 tab screens uniformly ignore safe area.
- `.animation(nil, value: activeTab)` on the action bar to prevent arc-drag during tab-driven layout changes (BottomBarV2.swift:306-307).
- State swaps after animated commits always in `Transaction{disablesAnimations=true}` (Player.swift:331-345, BottomBar.swift:373-390).
- V2 bars use `Button(.plain)` + `.simultaneousGesture(DragGesture(minimumDistance:0))` for press state; classic uses `.onTapGesture` + same drag — pick one convention.
- Environment-object web: bars read `NowPlayingState`, `CollectionState`, `OfflineModeState` via `@EnvironmentObject`; new app will want an analogous `ActionBarState` (mode enum + per-service now-playing payloads) injected at root (pattern: MusicApp.swift:55-74).

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift — tab row (349-392: equal-width 32pt template-icon buttons, press 0.92/.smooth(0.15), hit-area recipe), chromeBackground (394-418: VariableBlur 12 + gradient h120), scalar-progress chrome choreography (47-252)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayerV2.swift — 56pt capsule pill: material stack, progress fill, rotating cover, hairline stroke; direct base for the morphing action bar
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/Player.swift — 2D swipe pager: axis lock (8pt), commit threshold span*0.2 with predictedEndTranslation, rubber-band 0.25, .easeInOut(0.3) commit + Transaction cleanup; seeded infinite grid + neighbor preloading
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/AnimatedIconButton.swift — two-icon spring cross-morph (.spring(0.3, 0.6, blend 0.5), hidden scale 0.4) for animated active tab / play-pause states
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/PlayPauseButton.swift — circular button with bg pulse 0.8→1.0 spring(0.3, 0.8) + light haptic
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/TopNavBar.swift — text tabs + spring dot indicator (.spring(0.6, 0.75)); TopNavBarBackground double-VariableBlur top chrome (164-204)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/NavBar.swift — ScrollOffsetPreferenceKey + trackScrollOffset extension (5-31, 243-247); scroll-linked bar bg fade; ultraThinMaterial circle/capsule button recipes
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBar.swift — window-pinning offset hack for full-bleed vs safe-area tabs (23-42); CollectionTabCovers 3-card shuffle animation (205-393)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayer.swift — TimelineView vinyl rotation with frame-lerp decel; CoreHaptics continuous play-start haptic; cover crossfade swap
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/MusicApp.swift — AppTab enum + Binding-driven chrome, per-tab NavigationStack/NavigationPath, BottomBarStyle @AppStorage feature flag, EnvironmentObject injection at root, two-phase fade+blur sub-tab content swap (196-237)
- VariableBlur SPM package (github.com/nikstar/VariableBlur, branch main) — VariableBlurView(maxBlurRadius:direction:startOffset:) used for all frosted bar edges

## OPEN QUESTIONS
- Action bar morph: are the 4 states equal-height (fixed 56pt pill with content crossfade, MiniPlayerV2-style) or do search/movie states change the pill's height/width (requires matchedGeometryEffect or explicit frame interpolation not present in the codebase)?
- Does the action bar state follow the active tab automatically (tab switch = morph trigger) or is it driven by playback state independently of which tab is open?
- Search state: is it a tappable pseudo-field that opens a full search screen, or a real focused TextField inside the pill (keyboard avoidance would interact with the bar's ignoresSafeArea pinning)?
- 5 tabs: should the active state use the existing filled/outline asset swap without animation (BottomBarV2 style), the spring cross-morph (AnimatedIconButton style), or a moving indicator (TopNavBar dot style)?
- Will any of the 5 service screens be full-bleed like Player (hides the frosted chrome background, needs the window-pinning fix), or do all keep the blur bar?
- Should the movie player state on the action bar show video progress/thumbnail, and does tapping it open a Player.swift-style vertical pager for movies?