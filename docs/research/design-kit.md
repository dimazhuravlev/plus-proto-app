# MusicPlayer design-system & effects kit — catalogue

Repo root: `/Users/dimazhuravlev/Repos/MusicPlayer`. All paths below relative to that unless absolute. Pure SwiftUI prototype, iOS-only, dark (black) surface everywhere. One external dep: local SPM package `VariableBlur/`.

## 1. Colors — `MusicPlayer/Colors.swift` (13 lines)
Minimal `extension Color`:
- `fill1` = `.white` (primary label)
- `fill5` = white 0.6 (inactive tab/secondary)
- `subtitle` = white 0.5
- `accent` = `Color(red:0.64, green:0.2, blue:1.0)` ≈ #A433FF (purple)
- `offlineBannerBackground` = #1C1C1E, `offlineBannerSubtitle` = #8E8E93

Secondary palette in `MusicPlayer/Yasmina/YasminaTokens.swift:9-30` (`ymFillOne/.ymFillInverted/.ymFillEight(0.15)/.ymFillNine(0.08)/.ymAccent #A332FF/.ymButtonPrimary(0.10)/.ymButtonInverted/.ymSurface(black)/.ymDivider(0.15)/.ymCheckboxBorder(0.08)`). Note two nearly-identical purples: #A433FF vs #A332FF.

De-facto conventions (repeated everywhere, not tokenized): card fill `Color.white.opacity(0.08)`; hairline stroke `Color.white.opacity(0.08–0.1), lineWidth 0.66–1`; skeleton fill `white 0.1` (AlbumSkeletonScreen.swift:25); scrim = `.ultraThinMaterial` + `black 0.48–0.52` + grain.

## 2. Fonts — `MusicPlayer/Fonts/`
Font files that exist (only 2): `YangoText-Medium.ttf`, `YangoGroupHeadlineAR-ExtraBold.otf` (in `MusicPlayer/Fonts/`).
- `CustomFonts.swift`: `Font.Headline1…5` = YangoGroupHeadlineAR-ExtraBold at 48/40/32/28/24; `Font.Title1(24)/Title2(18)/Text1(15)/Text2(13)/Text3(11)` = YangoText-Medium. Plus `CustomFontFamily` string constants.
- `FontManager.swift`: singleton `FontManager.shared.registerFonts()` — runtime `CTFontManagerRegisterFontsForURL` registration (called at app start, MusicApp.swift:12). Fonts are NOT in Info.plist — registered at runtime, so new project must copy this pattern or add UIAppFonts.
- `FontDebugger.swift`: dead utility, prints hardcoded font names; safe to drop.
- Figma-exact typography modifier: `YasminaTokens.swift:49-86` `FigmaTextStyle` ViewModifier — compensates Figma explicit lineHeight via `lineSpacing(delta) + padding(.vertical, delta/2)`; exposed as `.ymHeadlineS()/.ymHeadlineL()/.ymTextM()/.ymButtonLabel()`. `YasminaFont.hasBoldText` runtime check for missing YangoText-Bold with fallback (YasminaTokens.swift:40-43).

## 3. Haptics
- `MusicPlayer/CustomHaptic.ahap` — NOT a real AHAP file: contains a Swift CHHapticEngine code snippet (continuous event, intensity 0.80, sharpness 0.40, attack 0.76, duration 0.40). Referenced by nothing (`grep CustomHaptic` → 0 hits in .swift). Treat as reference-only/dead.
- `MusicPlayer/Yasmina/YasminaHaptics.swift` (95 lines) — the real reusable haptics engine. Singleton `YasminaHaptics.shared`. API: `prepare()` (pre-warms UIImpactFeedbackGenerators + CHHapticEngine, ~50ms saved on first pattern; resetHandler restarts engine after backgrounding), `teardown()`, `snap()` (light), `reelTick(intensity:)` (rate-limited to 0.04s gap — carousel drum ticks), `select()` (light 0.8), `step()` (medium), `plug()` (composite CoreHaptics pattern: sharp transient 1.0/0.95 + body transient 0.62/0.30 at +0.045s, fallback rigid impact). Deps: CoreHaptics, UIKit, QuartzCore.
- Ad-hoc haptics elsewhere: `UIImpactFeedbackGenerator(style:.medium)` in OverflowMenu.swift:320, NewReleaseCard.swift:60, ShareOverlay.swift:441; `UINotificationFeedbackGenerator().notificationOccurred(.success)` OverflowMenu.swift:314. MusicApp.swift:139-140 has `offlineFlashHapticEngine/Player` + AVAudioPlayer for the flash transition.

## 4. AMBILIGHT-RELEVANT PIECES (flagged for the new app)

### 4a. `ImageLoader.averageColorPair(url:)` — `MusicPlayer/Features/CachedAsyncImage.swift:73-88` ⭐ core ambilight primitive
Extracts average colors of top/bottom halves of a remote image via `CIAreaAverage` (`UIImage.averageColor(ciRegion:)` :104-127), darkens topHalf by 0.3 (`UIColor.darkened(by:)` :130-137), caches in `topHalfColorCache/bottomHalfColorCache` (NSCache keyed by NSURL). Used by Player.swift:498-507 (`fetchDominantColor`, animated `withAnimation(.easeInOut(0.4))` into `slideColors[GridIndex]`), rendered as vertical LinearGradient behind slide: stops `bottomHalf.op(0)@0 → bottomHalf.op(0.45)@0.45 → topHalf.op(0.7)@1.0` (Player.swift:223-225). This is exactly the "blurred color background from cover" mechanic — reuse for cards' colored halos: feed cover URL → color pair → radial gradient/blur halo behind card.
Same file: `CachedAsyncImage` view (url + assetName fallback, placeholder `white 0.08` rect), `ImageLoader.load/preload` (NSCache 200 items/100MB + URLCache 50/200MB).

### 4b. `OfflineGlowBackground` — `MusicPlayer/Features/OfflineGlowBackground.swift` ⭐ the glow/blob engine
- `WobblyBlobShape` (:20-59): organic blob `Shape` — radius = sum of 9 sines over angle with tanh clamp, `phase` animates wobble; `useRectAspect` toggles stretch-to-rect vs fixed 1.24/0.78 aspect. 288 path steps.
- `OfflineMainBlobConfig` (:62-79): width/height/blurRadius/offsetY/rotationPeriodSeconds/opacityBreath range+period/phaseSpeed/stretchToAspect/clipsToBounds.
- `OfflineAccentBlobsConfig` (:82-97): 3 blob sizes, blurRadius, opacityMax/period, verticalRangeFactor, horizontal margins, phaseSpeed.
- `OfflineGlowBackground` view (:101-217): `TimelineView(.animation minimumInterval 1/30, paused:!isPresented)` drives main radial-gradient blob (`RadialGradient(mainCenter→mainEdge, center:(0.5,0.44))` + `.blur(cfg.blurRadius)` + breathing opacity) + 3 drifting accent blobs on Lissajous-like paths (:185-198) with sine-modulated opacity. `entranceProgress` 0…1 = layer opacity + Y-slide-in. `allowsHitTesting(false)`.
- Palette `OfflineBlobPalette` (:4-15): mainCenter #A332FF, mainEdge #5700B5, accents #E9001F / white / #FF6A00 (1:1 with shader).
This is a parameterized, screen-agnostic "neon glow cloud" — directly reusable for the "Моя Волна" orb halo and edge glows. 4 existing consumers with different configs: `OfflineHeaderGlow.swift` (glow bleeding from under top navbar, main blob w*2 × totalH*1.5, blur 36, offsetY -totalH, breath 0.7…0.85; accents blur 50, verticalRange -0.85…-0.42), `OfflinePullGlow.swift` (mirror at bottom under mini-player, progress-driven entrance with entranceExtraYFactor 0.5, progressLift 24), `OfflinePromptLayer.swift:51`, `OfflineWidget.swift:30`.

### 4c. `OfflineFlash.metal` + `OfflineFlashOverlay.swift` — full-screen shader transition
- `Shaders/OfflineFlash.metal`: `[[stitchable]] half4 offlineFlash(...)` colorEffect — coverProgress-driven "train" of 1 background wobbly splat (#A332FF center) + 7 colored gauss blobs (palette hardcoded :118-124: #5700B5, blue-violet 120/40/210, #A700BA, pink-magenta 210/30/160, #E9001F, coral 255/70/95, #FF6A00) rising bottom→top with per-blob stagger/speed/driftX (struct B table :162-168), white curved wave band (gauss core+halo+outer σ 0.095/0.24), white side rim "snakes" along left/right edges, additive warm grain. `reversed` flips direction. Alpha = flashMask*exitFade (premultiplied, transparent where uncovered). Also two standalone grain kernels: `grainOverlay` (additive + multiplicative 0.94–1.06) and `grainOverlaySoft` (additive-only, for photo/UI overlays).
- `Features/OfflineFlashOverlay.swift`: SwiftUI wrapper; API: `coverProgress/exitProgress/isReversed/blobColorSlots [7 palette indices]/blobRadii [7]/coloredBlobsOpacity/redirectCoverProgress`; plus a "lower haze" green/purple layer with its own opacity curve (:90-146, note `lowerHazeDebugProminent = true` currently forces debug green #00FF8C). Uses `ShaderLibrary.offlineFlash(...)` via `.colorEffect` + `.drawingGroup`. Orchestration lives in MusicApp.swift (@State offlineFlash* at :123-141, incl. CHHapticEngine + AVAudioPlayer sync).

### 4d. `Glow Button/` — Metal neon orb ⭐ direct "Моя Волна" candidate (not in the requested list but is the closest existing analog)
- `ShaderButtonView.swift`: `UIViewRepresentable` over `ShaderButtonBackgroundView: MTKView` (compute kernel `shaderMain` in `Glow Button/Shaders/Gradient.metal`, 302 lines: 3 rotating noisy ring-blobs (simplex noise displaced), currently all-white with opacity 0.15 defaults, edge-boost where rings overlap, alpha*=0.1). Chainable modifier API: `.interaction/.reactTop/.reactMiddle/.reactBottom/.audio(a4,a5)/.timeMultiplier/.offset(x:y:)/.interactionAt/.topOpacity/.middleOpacity/.bottomOpacity/.opacity(t,m,b)/.sparkStrength/.randomize(seed:)/.scale`. `Uniforms.swift` mirrors `Shaders/Shared.h` (field order must match). `MetalUtils.swift` loads custom.metallib or default library. Used at BottomBar.swift:70 (80×80 center tab glow). To make it a colored neon orb, change `whiteColor` in Gradient.metal or parameterize colors via uniforms.

### 4e. `LowerHazeGrainOverlay.swift` — film-grain layer
`LowerHazeGrainOverlay(width:height:isPaused:)` — black rect + `ShaderLibrary.grainOverlaySoft` colorEffect inside `TimelineView` (1/30s), `.blendMode(.screen)` so black base adds no gray veil. `ModalOverlayScreenMetrics` (UIScreen full-bounds incl. home indicator). Opacity presets `LowerHazeGrainLayerOpacity`: offlinePrompt 0.5, playerSlide 0.45, newReleaseCard 0.45, modalScrim 0.35. Used on modal scrims (OverflowMenu.swift:128, ShareOverlay.swift:112) and card backgrounds (NewReleaseCard.swift:130). Reusable as-is for "expensive dark" texture over glow backgrounds.

### 4f. `VariableBlur/` local SPM package — progressive blur ⭐
`Package.swift`: name VariableBlur, iOS 13+, single target, no deps. Single source file `Sources/VariableBlur/VariableBlur.swift`: `VariableBlurView(maxBlurRadius: CGFloat = 20, direction: .blurredTopClearBottom | .blurredBottomClearTop, startOffset: CGFloat = 0)` — UIViewRepresentable over UIVisualEffectView whose backdrop layer filters are replaced with private `CAFilter variableBlur` masked by a CI linear-gradient image (private API; README notes no App Store rejection observed; nikstar/VariableBlur fork of jtrivedi). Used in NewReleaseCard.swift:123 (`maxBlurRadius:28, .blurredBottomClearTop`, height = cardWidth*0.78 bottom text-legibility fade over mirrored artist photo) and BottomBar/TopNavBar frosted gradients. For new app: add as local package dependency again (path-based), or copy the one file.

### 4g. Yasmina glow assets approach (pre-baked PNG glow)
Figma SVG filters don't render in Xcode → glows exported as rasterized PNGs with baked gaussian blur. `YM.GlowLayer {canvas, offset}` (YasminaTokens.swift:122-138) positions oversized glow PNGs precisely. `YasminaAvatar.swift`: TimelineView rotates two glow-spot PNGs opposite directions (t*20 and t*-27.7 deg/s) with `breathe()` sine opacity (low 0.84/0.88, periods 5.4/3.9s, phase offset) under static glyph — cheap "alive" neon avatar; direct pattern for an Алиса orb. `SpeakerGlowRing.swift`: PNG ring (canvas 87 = 39 + 2×24 blur), breathing via `.easeInOut(YMTiming.blinkHalfPeriod 0.75).repeatForever(autoreverses:true)` opacity 0↔1.

## 5. Other requested components

### `ShimmerModifier.swift` (33 lines)
`.shimmering()` — overlays moving LinearGradient (clear/white 0.15/clear), `offset(x: phase*200)`, masked by content, `.linear(1.2).repeatForever`. Used only in Player.swift:249,253. Loading-state shimmer; pairs with AlbumSkeletonScreen (which itself has NO shimmer — static white-0.1 shapes).

### `HeartExplosionView.swift`
`HeartExplosionView(centerPosition: CGPoint)` — fire-and-forget particle burst on mount: 20–30 "like-active" template images (white), random 2π angle, radius 20–100 + jitter ±30, rotate ±180 + 45–90, movement 0.4s `.smooth`, staggered appear 0–0.2s / disappear 0–0.3s, exit = opacity→0 + size→8 + blur→12. Driven by DispatchQueue.asyncAfter mutations of `@State hearts`. zIndex(-1000). Consumer wraps in `if showHeartExplosion` + auto-clear after 2.0s (NewReleaseCard.swift:232-241).

### `Gyro3DTilt.swift` + `GyroManager.swift`
`.gyroscope3DTilt(_ gyro: GyroManager, intensity: Double = 11, perspective: CGFloat = 0.88)` — two `rotation3DEffect`s (pitch→X axis, -roll→Y), `.interactiveSpring(response:0.38, damping:0.74)`. `GyroManager` (Features/GyroManager.swift): `ObservableObject` singleton `.shared` (must be single instance — multiple CMMotionManager break updates), publishes `roll/pitch/yaw` (clamped ±0.6 rad, baseline-relative), 60Hz; falls back to accelerometer, and on Simulator runs a CADisplayLink sine demo (`pitch=sin(t*0.9)*0.18`). Also consumed by `ParallaxEffect` (BubbleLayout.swift:256-303): size-aware parallax offset (roll/pitch*40*scale, smaller bubbles move more, `pow(1-d/120, 1.8)` clamp 0.4…1) + bounds clamping. Ready-made for gyro parallax on ambilight cards.

### `Toast.swift`
`ToastManager.shared.show(title:cover:coverURL:duration:4)` singleton + `.toast(isPresented:config:onTap:)` root modifier. Pill (cornerRadius 80, `.ultraThinMaterial` + `black 0.01` + `.blendMode(.overlay)` + hairline stroke, `.compositingGroup()`), 32pt cover with separate tilt-drop entrance (rotation -12→6, offsetY -30→0, spring(0.5,0.75) delayed 0.15), slide from top (yOffset -100→-16), dismiss = fade + blur 16 over 0.5s. Timer-token pattern prevents stale auto-dismiss (:121-123).

### `OverflowMenu.swift` (629 lines)
Long-press context overlay: scrim (ultraThinMaterial + black 0.52 + grain in `.background{}.ignoresSafeArea()` so content stays in safe area — pattern at :119-138), centered entity card (254w, cover 176, `white 0.08` bg, default tilt 3°, entry from -4°), 4 emoji reaction buttons with two drag modes — absolute (thresholds 100/160pt) and sequential (step 80pt cursor over 0…3 scale with per-crossing haptics), grab-anchor rotation (`rotationSensitivity 0.14 * (ax*dy - ay*dx)` around UnitPoint of touch), vertical dampening 0.35, button parallax follow (±14pt cap), staggered open (blur 0.25 → card+buttons after 0.15, emoji stagger 0.06). State via `OverflowMenuState` environmentObject with `scheduleRemovalAfterAnimation`. Session-token guards (`openAnimSession: UInt64`) against animation races.

### `ShareOverlay.swift` (532 lines) + `docs/ShareOverlay-logic.md`
Same scrim/card architecture; card is flick-dismissable: `ShareCardDragConfig` — dismissDistanceThreshold 120pt OR velocity 300 (predictedEnd - location) → fly-out 720pt along gesture vector `flyOutDuration 0.42` + velocity boost 0.3 then blur fade 0.24; release <12pt = pure spring back, otherwise inertia (translation*0.25, rotation*0.2) then spring(0.52, 0.72). `dragAwayProgress` (0…1 over 120pt) simultaneously fades/blurs (6pt) bottom share block and modulates scrim black 0.48–0.60. Grab-anchor rotation sensitivity 0.18; card height measured via PreferenceKey for correct rotation anchor. Doc file explains UX intents in Russian — good spec for reimplementation.

### `BubbleLayout.swift`
Deterministic circle packer for avatar-bubble cards: `BubbleLayout(index:).placedBubbles(in:bubbles:[BubbleSpec], textAreaHeightRatio: 0.28)` — sorts big→small, spiral search around desired point (seeded RNG `SeededGenerator`, seed `0xD1E5C0DE ^ index*1315423911`), falls back to 8×8 grid scan then tiny corner; avoids reserved text rect; sizes shrink up to ×0.92⁴/0.9⁶ to fit. Also exports `SeededGenerator` (LCG RandomNumberGenerator, reused by Player grid + FavoriteCard) and `ParallaxEffect` (see Gyro above). `allArtistImageNames` — 39 bundled asset names.

### `GenreCard.swift`
Consumer of BubbleLayout + ParallaxEffect + GyroManager (via `@EnvironmentObject`): rounded 16 card (`white 0.08`/selected white with white-0.5 glow shadow radius 8), title Headline3 + description, 10 deterministic BubbleSpecs rotated/jittered by index, gyro parallax with `.smooth(0.25)` per-axis animations. Data coupled to `GenreCatalog.shared`.

### `FavoriteCard.swift`
Stacked pair of 80pt covers with deterministic random tilts (left -18…-6°, right 6…18°, x ∓14–30, y ±8; seed from id+cover names via mix-hash :137-155), random z-order, pressed state spreads/tilts further + scale 1.1, `.smooth(0.25)`. Cover: white-0.05 bg, hairline 0.66, shadow black 0.3 r16 y10.

### `NewReleaseCard.swift`
Big 0.85-screen-width card (h = w*1.34): full-bleed artist photo + mirrored copy below fold + `VariableBlurView(28, .blurredBottomClearTop)` + grain overlay 0.45 + heart-explosion overlay + like/play buttons with tap-suppression (`SuppressNavigationModifier` :275 — LongPress(0) hack to keep card Button from firing), press scale 0.98 ButtonStyle with no-animation on press transaction (:69-80). Carousel included (`NewReleaseCarousel`). `NewReleaseData` model has Deezer fields (albumCoverURL etc.).

### `AlbumSkeletonScreen.swift`
Static skeleton (no shimmer): white-0.1 rects/circles/bars; layout: hero cover = screenWidth − 2×(0.1707·w) inset, 5 track rows 48pt thumb. Depends on ShowcaseNavState/OfflineModeState envObjects and scroll-offset tracking helper `trackScrollOffset(in:offset:)`.

### Yasmina flow (reference architecture for an "Алиса" narrative flow)
`YasminaFlow.swift` — 6-step single-screen flow; persistent layers (avatar/header/speaker stage) survive step changes; step transitions via `stepAlpha` value animation (NOT `.transition` removal — documented as broken for removal at :262-269), `switchStep` two-beat choreography (fade out 0.35 → apply → fade in 0.30), `illustrate(after:)` async gate lets steps inject animations between typewriter messages. `YasminaFlowModel.swift` — `@Observable` state (steps enum, heroProgress, cableProgress, stageEntrance, blinking, stepAlpha, per-step message scripts). `YMTiming` (YasminaTokens.swift:256-283) single source of truth: typewriter 1/30s per char, betweenMessages 0.40, stepExit 0.35/stepEnter 0.30, cable 0.30+0.70, blink 0.55+0.75 half-period, activation 8.0. `KeyboardObserver` (YasminaFlow.swift:395-421) for button-above-keyboard. `YasminaBubble.swift` — Figma-faithful bubble: white 0.12 fill + inner shadow + vertical-gradient stroke (0.9/0.15/0.9 × 0.1) + opaque backing to hide layers behind.

## 6. Cross-cutting patterns worth copying to the new app
- TimelineView(.animation, minimumInterval: 1/30, paused:) for all ambient loops; `allowsHitTesting(false)` on decorative layers.
- Config enums per feature (`ShareCardDragConfig`, `OverflowCardConfig`, `YMTiming`) — every magic number named and commented.
- Scrim recipe: `.background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(.black.opacity(~0.5)); grain } .opacity(blurOpacity).ignoresSafeArea() }` keeps content in safe area.
- Session-token (`openAnimSession/timerToken/epoch UInt64`) guards on every DispatchQueue.asyncAfter choreography.
- SeededGenerator for deterministic "random" layout (stable across rerenders).
- `[[stitchable]]` SwiftUI colorEffect shaders for full-screen effects; MTKView compute kernel for the always-running orb; pre-baked PNG glows where Figma filters can't be reproduced.
- App orchestration: environmentObjects from root (NowPlayingState, CollectionState, GyroManager, OfflineModeState, overlay states), manual ZStack navigation, `FontManager.shared.registerFonts()` at init (MusicApp.swift:12).

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift:73 — ImageLoader.averageColorPair: CIAreaAverage top/bottom cover-color extraction + caches; THE ambilight color source
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/OfflineGlowBackground.swift — WobblyBlobShape + OfflineMainBlobConfig/OfflineAccentBlobsConfig + OfflineGlowBackground: fully parameterized animated glow-blob cloud (recolor palette for ambilight halos)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Glow Button/ — ShaderButtonView (MTKView compute shader, chainable API) — closest existing analog of a neon 'Моя Волна' orb; recolor whiteColor in Shaders/Gradient.metal
- /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur/Sources/VariableBlur/VariableBlur.swift — VariableBlurView(maxBlurRadius:direction:startOffset:) progressive blur (private CAFilter), single file, add as local SPM or copy
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/LowerHazeGrainOverlay.swift + Shaders/OfflineFlash.metal grainOverlaySoft — screen-blend film grain layer with opacity presets
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/Gyro3DTilt.swift + GyroManager.swift + ParallaxEffect (BubbleLayout.swift:256) — gyro tilt/parallax with simulator demo fallback
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Yasmina/YasminaHaptics.swift — prepared CoreHaptics engine wrapper (snap/reelTick/select/step/plug)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/FontManager.swift + CustomFonts.swift — runtime font registration + Font.Headline1-5/Title/Text tokens (YangoText-Medium.ttf, YangoGroupHeadlineAR-ExtraBold.otf)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/Toast.swift — ToastManager singleton + pill toast with tilt-drop cover entrance
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/ShareOverlay.swift + docs/ShareOverlay-logic.md — flick-dismiss card overlay (thresholds/inertia documented)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/OverflowMenu.swift — long-press card + drag-scale emoji reactions overlay
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/ShimmerModifier.swift — .shimmering() loading shimmer
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/HeartExplosionView.swift — like particle burst
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BubbleLayout.swift — seeded circle packer + SeededGenerator deterministic RNG
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Yasmina/YasminaTokens.swift — FigmaTextStyle lineHeight-exact text modifier + GlowLayer pre-baked-PNG glow positioning + YMTiming choreography enum
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Yasmina/Components/YasminaAvatar.swift — two counter-rotating breathing glow PNGs under static glyph (Алиса-orb pattern)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Shaders/OfflineFlash.metal + Features/OfflineFlashOverlay.swift — full-screen stitchable blob-flash transition shader (palette hardcoded, coverProgress-driven)

## OPEN QUESTIONS
- Should the new app keep the Yango fonts (YangoText/YangoGroupHeadline) or switch to Yandex Sans/YS Text for the Яндекс Плюс brand — and does a font file for that exist?
- Ambilight halos: is the desired look the static blurred-color glow (averageColorPair → RadialGradient + blur, cheap, per-card scalable) or the animated wobbly-blob glow (OfflineGlowBackground, ~1 TimelineView per instance — how many animated halos on screen at once is acceptable?)
- Для 'Моя Волна' orb: reuse the MTKView Gradient.metal shader (needs recoloring + always-on GPU cost) or rebuild as a stitchable SwiftUI shader / pre-baked PNG layers like YasminaAvatar?
- OfflineFlashOverlay has lowerHazeDebugProminent = true (debug green haze) — is that the intended current look or leftover debug to ignore when porting?