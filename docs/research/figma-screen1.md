# SHOWCASE SCREEN 1 — "Персональная лента" — Figma implementation spec
File: 0HzFEKtm9oYdkksrDg7U14, frame `2004:10701` "screen", 402×2188pt (iPhone 16 Pro width 402). All coords below are LOCAL to this frame, in pt. Fetched via get_design_context per child (React+Tailwind reference) + get_metadata + get_variable_defs. Asset URLs expire ~7 days — re-export by node ID.

## 0. Global / background
- Base: black (#000) under everything.
- `2004:10702` "main blurred bg": rounded-rect **804×2269 at (-201, -81)** — exactly 2× screen width, centered, bleeds 201pt off each side and 81pt off top. Image fill (collage of all covers on the screen), **layer blur 100, opacity 0.40**. This is the only ambient wash; no gradient fill on the frame itself.
- SwiftUI: `Color.black.ignoresSafeArea()` + `Image("feedAmbientCollage").resizable().scaledToFill().frame(width: W*2).blur(radius: 100).opacity(0.4)` behind ScrollView content (can be regenerated at runtime by stacking the 4 covers + blur instead of shipping the PNG).

## 1. Design tokens (get_variable_defs on 2004:10701)
- `Plus/Solid One` **#D88DFC** (progress fills — Plus purple)
- `Buttons/Primary` **#FFFFFF1A** (white 10%) — circular buttons bg
- `Buttons/Secondary` **#FFFFFF14** (white 8%) — Rate emoji container bg
- `Fill/One` #FFF; `Fill/Six` #FFFFFF66 (40%, inactive tab label); `Fill/Nine` #FFFFFF14 (glass borders on bars); `Fill/Ten` #FFFFFF0F; `Fill/Subtitle` #FFFFFF80
- `System/iOS Navbar darkBlur` #141414B2; `BG Blur/System/iOS Specific` = background blur r70
- Hardcoded recurring: card borders `rgba(255,255,255,0.08)` @1pt (covers) and `rgba(255,255,255,0.06)` @0.66pt (glass buttons/blocks); ambilight blur radius **28** everywhere.

Typography (families: "YS Display", "YS Text", "Yandex Sans Text"; MusicPlayer already bundles YangoText-Medium.ttf as the YS Text stand-in):
- Header H1: **YS Display Bold 32/36, tracking -0.2**
- Rate title & search placeholder: **YS Display Bold 20/26**
- Card captions/labels: **YS Text Medium 15/18, tracking -0.2**
- Progress captions: **YS Text Medium 13/16, tracking -0.2**
- Reader excerpt: **YS Text Medium 18/20, tracking -0.2**
- Tab labels: **Yandex Sans Text Medium 11/14**
- Status bar: SF Pro Text Semibold 17 (ss03)

Text-gradient pattern (used on nearly every caption): horizontal LinearGradient as `foregroundStyle`, tinted toward the artwork side:
- Header title: white (left) → white 60% (right)
- Movie caption: **#A7CAC6** (left, toward poster) → white (right)
- Book caption: white (left) → **#BCEBFB** (right, toward blue book; text right-aligned)
- Vibe title: white (left) → white 70% (right); vibe subtitle: white→white60 + extra opacity 0.6
- Rate labels: white (left) → white 70% (right)

## 2. Like/Dismiss button (shared component, Figma component 11:9189 "Size=md 40px, Type=primary, Icon=only")
- 40×40, circle (r=1000), padding 10, icon 20×20 white
- bg `Buttons/Primary` #FFFFFF1A, border 0.66pt rgba(255,255,255,0.06), **backdrop-blur 20**
- Icons: heart (like) node path `…;19:3851` inset 15.05/8.33/10.88/8.33%; X (dismiss) node path `…;19:6160` inset 17.3%
- Pair layout: HStack gap **6** (like left, dismiss right). SwiftUI: Circle + `.background(.ultraThinMaterial)` tuned or Color.white.opacity(0.1) + blur behind.

## 3. Cards (top → bottom)

### 3.1 Header `2004:10773` — (24, 70.79) 354×114.14
- Title `2004:10774`: x24–x378, top 72, 3 lines of 36pt = h108. Text with wide inline gaps: `Тебе нравится ␣␣␣ Joy Division, ␣␣ Балабанов\nи ␣␣ Дэвид Гребер`. Chips absolutely positioned over the gaps:
  - `2004:10775` artist avatar: **circle 36×36, rotation -4°**, photo fill (Joy Division), abs (244.79, 73.30) bbox 38.42²
  - `2004:10776` movie poster chip: **29×40, r3, border 1pt white8%, rotation +5°**, abs (152.8, 103.86)
  - `2004:10777` book chip: cover **28×41 rotation -4°** (`2004:10778` PNG) + spine strip 3×41 (`2004:10779` PNG), abs (47.6, 144.03)
- SwiftUI sketch: hand-positioned `Text` + 3 small chip views in a ZStack (don't fight AttributedString inline images — chips are rotated, easier as overlays with fixed offsets), or iOS17 `Text` interpolation with `Image` then apply rotation per chip is impossible → ZStack wins.

### 3.2 Movie card `2004:10766` — (25.06, 220.48) 348.28×298.51
- Ambilight `2004:10767`: same poster image, **180×270, r12, rotation -3°, layer blur 28, opacity 0.70**, exactly behind cover (centerX ≈ 122 local)
- Cover `2004:10768`: **180×270 (2:3), r12, border 1pt white8%, rotation -3°** («Идеальные дни» / Perfect Days poster)
- Caption `2004:10769`: (190.66, 391.65) w182.68 — sits to the RIGHT of poster, bottom-third; YS Text Medium 15/18, gradient #A7CAC6→white; text: «Обыкновенный уборщик ищет красоту в каждом мгновении. Шедевр Вима Вендерса о магии жизни»
- Buttons `2004:10770`: like+dismiss pair at (50, 478.99), i.e. under the poster's lower-left
- SwiftUI: `ZStack(alignment:.topLeading)` { cover.blur(28).opacity(0.7); cover.clipShape(RR 12).overlay(stroke) }.rotationEffect(.degrees(-3)) + offset caption + buttons. Blur copy and sharp copy share one rotation container.

### 3.3 Album card `2004:10757` — (31, 562) 268.67×206
- Ambilight `2004:10758`: **180×180, r12, rotation +2°, blur 28, opacity 0.70**
- Cover `2004:10759`: **180×180 (1:1), r12, border 1pt white8%, rotation +2°**, centerX ≈ 206.6 local («Аквариум — Равноденствие»)
- Titles `2004:10763`: (31, 674) w107, VStack: «Аквариум» 15/18 white; «Равноденствие» 15/18 white opacity 0.5 — sits to the LEFT of cover, overlapping its lower-left
- Buttons `2004:10760`: pair at (122.68, 728) below cover center-left
- Note left/right alternation vs movie card (cover left→caption right, then cover right→caption left).

### 3.4 Book card `2004:10745` — (15, 787.96) 415.54×283.31 — **bleeds 28.5pt off the RIGHT edge**
- "isometric book" `2004:10746` at right (contents x≈198.5–430.5):
  - Ambilight `2004:10747`: cover image **157.98×226.31, rotation -9.46°, skewX 0.39°, blur 28, opacity 0.30**
  - Front cover `2004:10749`: «Технофеодализм» (Янис Варуфакис, blue) **157.86×226.09, rotation -9.47°, skewX 0.36°**
  - Page-block bottom `2004:10748`: SVG 157.35×34.10 at (254, 1022.4) — white page edges
  - Spine `2004:10750`: SVG 39.65×230.90 at (216, 825.6)
  - Spine wrap strip `2004:10751`: PNG 10.19×226.10, **rotation -9.84°**
  - Recommendation: export the whole isometric book `2004:10746` as ONE flattened PNG @3x (5 layers with skew are not worth rebuilding in SwiftUI); keep ambilight as separate runtime blur of cover if animated.
- Caption `2004:10753`: (15, 886) w192, right-aligned, 15/18, gradient white→#BCEBFB (blue at right edge); text: «Что пришло на смену капитализму и как это изменило мир? Новый взгляд на экономику»
- Buttons `2004:10752/10754`: VStack(alignment:.trailing, gap 8) under caption → pair at abs (121, 966)

### 3.5 My vibe card `2004:10733` — (-15, 1008) 338×316 — **bleeds 15pt off LEFT edge**
Orb construction (left half), 3 layers bottom→top:
1. `2004:10735` "color": ellipse **150.48×150.48 at (59.46, 1101.92)**, violet/magenta radial glow; exported SVG spills -53.33% each side ⇒ effective **layer blur ≈ 80** (halo diameter ~310)
2. `2004:10736` "shader": rect **317×316 at (-15, 1008)**, **mix-blend color-dodge, opacity 0.70**, fill = Figma procedural shader (account library "Fractal noise") — renders as textured noise sparkle over the glow. NOT exportable as code → rasterize node to PNG, or reuse Metal noise/grain from MusicPlayer
3. `2004:10737` "electro_dance" instance: **100.32×100.32 at (83.29, 1127)** = neon-magenta «Моя Волна» wave glyph: sharp Vector 87.74² (`I2004:10737;61:12652` SVG) + glow duplicate 109.67² (`I2004:10737;61:12653` SVG)
- Screenshot confirms: purple neon glyph with a large violet halo on black.
- Text col `2004:10738`: (208, 1118) w115, VStack gap 12: «Моя Волна» 15/18 gradient; «Атмосферный постпанк, когда внутри пасмурно» 15/18 gradient, opacity 0.6, w124; then buttons pair gap 6
- SwiftUI: prefer reusing MusicPlayer `Generator.swift` (AVPlayer shader-video orb) or static: Circle glow (RadialGradient or blurred Circle r≈80) + glyph Image + noise overlay `.blendMode(.colorDodge).opacity(0.7)`.

### 3.6 Continue-reading book card `2004:10714` — (24, 1308.99) 354×272.01
- Block `2004:10717`: **354×247 at (24, 1334), r16, bg white10%, border 0.66 white6%, backdrop-blur 20, clipped, padding 8**
  - Excerpt `2004:10718`: w322 h532 positioned at **left 15.34, top -46.66** inside block (starts mid-paragraph, clipped top+bottom) — YS Text Medium **18/20** white; long Варуфакис excerpt («Пиль предполагал, что у рабочих не было другого выбора…»)
  - Top scrim `2004:10719`: 354×118 pinned to top, rounded-top-16, linear top→bottom: rgba(0,0,0,0.35) until 27.885% → transparent (legibility under timeline row)
  - Dismiss-only button `2004:10720`: 40×40 at top-right inset 7.34 (X icon; NO like button on this card)
- Timeline `2004:10721`: (109, 1346.55) w137 — row: «36%» 13/16 white50 + gap 6 + track **108×6 r8 white10** with fill **35.45% width, 6pt, r8, #D88DFC**; below: «Осталось 2 дня 5 часов» 13/16 white
- Mini book `2004:10730`: (40, 1308.99) 57×90.3, **rotation -4°**: blurred copy (blur 16, opacity 0.5) + sharp copy **51.06×86.95** (orange cover PNG `2004:10731`/`10732`, same image) — overlaps block's top-left corner, sticking up above it
- Glow `2004:10729`: instance 65×38 at (66.99, 1315), rotate 180 + flipY, 4 blurred-ellipse SVG layers (`I2004:10729;4892:31719…31722`) — warm glow behind mini book top
- SwiftUI: RoundedRectangle glass block + `Text` excerpt offset(y:-46.66) clipped + LinearGradient scrim + custom ProgressBar(h:6) + book thumbnail ZStack breaking out of clip (place book as sibling, not child).

### 3.7 Continue-watching movie card `2004:10703` — (-7.27, 1647) 409.27×313 — **bleeds ~7pt off LEFT edge**
- Ambilight `2004:10704`: video still **277×156, r12, rotation -5°, blur 28, opacity 0.50**
- Video frame `2004:10705`: **277×156, r12, border 0.66 white8%, rotation -5°, clipped**; content bottom-aligned (pt124 pb8 px8, gap 2):
  - Bottom scrim `2004:10706`: 277×35, black50→transparent upward
  - «Осталось 16 мин» 13/16 white
  - Timeline `2004:10708`: track **261×6 r8 white10 + backdrop-blur 6**; fill **212.76pt (81.5%), r8, #D88DFC**
- «ЗДЕСЬ БЫЛ ЮРА» logo `2004:10711` "orig 1": PNG **147×101 at (237, 1671)**, NO rotation, overlaps video frame's right side
- Dismiss button `2004:10712`: 40×40 at (16, 1647) — top-left, dismiss only
- Rate component `2004:10713`: **402×158 at (0, 1802)**, full-bleed width, VStack py8:
  - «Что думаешь?» YS Display Bold 20/26 white, centered (pt16 pb12 px16)
  - 4 equal columns (HStack px16; per column: pt8 pb6 px8, gap 8): emoji chip **52×52, r32, bg Buttons/Secondary #FFFFFF14**, emoji 24pt (lh28, "Yango Text" token style "Title S 24/Semibold"); label 15/18 gradient. Pairs: 👎 Нет · 😐 Ну такое · 👍 Супер · 😍 Шедевр
- SwiftUI: rotated ZStack(blur copy + AVPlayerLayer or still) + overlay logo PNG offset outside rotation + RateView(HStack of 4 VStack buttons).

## 4. Navbar / tabbar / action bar
- Top navbar `2004:10780` (0,-1) 402×160: scrim `2004:10781` 402×72 black50→transparent downward + iOS status bar 54pt (time 19:25 left px32, cellular 19.97×12 / wifi 17×12.5 / battery 27.33×13 SVGs right). No title, no blur (gradient only).
- Action bar `2004:10784` (0, 2024) 402×60: HStack px24 gap8:
  - Search field: flex-1, h60, r32, bg white10, border 0.66 `Fill/Nine`, **backdrop-blur 35**, px18: search icon 24 + placeholder «Хочу послушать...» YS Display Bold 20/26 rgba(255,255,255,0.3). Two hidden alt placeholders «Хочу почитать...» / «Хочу посмотреть...» (opacity 0, stacked gap 16) ⇒ designed rotating-placeholder animation.
  - Mini-player: 60×60, r32, same glass, round cover 48×48 (border 0.66 Fill/Nine); hidden (opacity 0) expanded state contains track name «Strawberry Line / Cocteau Twins» 13/16, love+pause icons 24, progress fill `Fill/Ten` ⇒ expandable mini-player.
- Tabbar `2004:10783` (0, 2088) 402×100:
  - Underlay gradient: 402×**210** anchored −110 above bar top — 16-stop eased vertical gradient black 0.9 (bottom) → 0 (top) (smooth ease, not linear; consider VariableBlur + gradient)
  - 5 tabs, each 60×62 (row px24, pt4, space-between): icon tile **40×40 r14 bg white10 border ~0.7 white4–6%** with service glyph SVG; label 11/14; active (Плюс) label white + brighter tile border + "pulse" glow SVG 50×43 behind tile bottom; inactive labels #FFFFFF66. Order: Плюс · Музыка · Кинопоиск · Книги · Алиса
  - Home indicator: 134×5 r100 white, container h34
- Feed content bottom padding must clear: action bar (2024) + tabbar (2088) ⇒ ~164pt + safe area.

## 5. Spacing rhythm (local Y, visual blocks)
header 72–185 → gap ~35 → movie 220–519 → gap 43 → album 562–768 → gap 20 → book 788–1071 → vibe 1008–1324 (bounding boxes OVERLAP because glow halos bleed; visual orb starts ~1100) → reading 1309–1581 (mini book sticks up to 1309) → gap 66 → watching 1647–1960 (incl. Rate to 1960) → gap 64 → action bar 2024 → tabbar 2088. Takeaway: irregular 20–66pt gaps, intentional overlaps; do NOT use a uniform LazyVStack spacing — per-card offsets or spacing array. Nothing may clip horizontally (cards bleed both edges): ScrollView content must not clip subviews.

## 6. Rotation summary (CSS deg, + = clockwise)
avatar chip -4°, poster chip +5°, book chip -4° | movie -3° | album +2° | isometric book -9.47° + skewX ~0.4° (spine strip -9.84°) | reading mini book -4° | watching video -5°. Alternating sign per card creates the "scattered on table" rhythm.

## 7. Ambilight recipe (recurring pattern, 5 uses)
Duplicate of artwork placed exactly behind sharp copy, same rotation: layer **blur 28**, opacity **0.70** (movie/album), **0.50** (video), **0.30** (isometric book); mini book uses blur 16 / 0.5. SwiftUI: one container per card → `ZStack { art.blur(28).opacity(o); art.clipShape(RR(12)).overlay(RR(12).stroke(.white.opacity(0.08))) }.rotationEffect(angle)`. Progress bars: capsule track h6 white10 + capsule fill h6 #D88DFC.

## 8. Assets to export (by node ID; current MCP URLs expire ~7d)
PNG @3x: movie poster (fill of `2004:10768`), album cover (`2004:10759`), book cover texture (`2004:10749`), isometric book flattened (`2004:10746` whole group — recommended), spine strip (`2004:10751`), mini orange book (`2004:10731`), video still (`2004:10705` fill), «ЗДЕСЬ БЫЛ ЮРА» logo (`2004:10711`), header avatar (`2004:10775`), header poster chip (`2004:10776`), header book chip (`2004:10778`+`2004:10779`), main bg collage (`2004:10702` fill), mini-player cover (action bar), **vibe shader noise rect `2004:10736` rasterized** (blend-critical).
SVG: like heart (`…;19:3851`), X (`…;19:6160`), vibe glyph (`I2004:10737;61:12652`), vibe glyph glow (`I2004:10737;61:12653`), vibe color ellipse (`2004:10735`), reading glow ellipses (`I2004:10729;4892:31719–31722`), tab icons: PLUS-SYMBOL `2004:9357`, Музыка Union `2004:9180`, Кинопоиск NNEEWW `2004:9176`, Книги `2004:9184`, Алиса Exclude `2004:9268`, pulse glow, search icon 24, status-bar cellular/wifi/battery.
For prototype with live APIs, PNG covers are placeholders — real covers come from TMDB/Deezer/etc., ambilight generated at runtime.

## 9. SwiftUI architecture sketch
- `ShowcaseFeedScreen`: ZStack { Color.black; AmbientCollageBackground; ScrollView(VStack per-card spacing array); TopScrim+StatusBar overlay; bottom overlay VStack { ActionBar; TabBar } with eased-gradient underlay }
- Shared: `GlassIconButton(icon:)` (40pt spec §2), `LikeDismissPair`, `AmbilightArtwork(image:size:corner:rotation:blurOpacity:)`, `PlusProgressBar(progress:width:)`, `GradientText(text:from:to:)` (foregroundStyle LinearGradient), `RateView` (4 emoji), `EntityChip` (header)
- Card views: `FeedHeaderView`, `MovieFeedCard`, `AlbumFeedCard`, `IsometricBookCard` (flattened PNG + caption), `MyVibeCard` (orb), `ContinueReadingCard`, `ContinueWatchingCard`
- Model: `FeedItem` enum(header, movie, album, book, vibe, reading, watching) driving ForEach.

Gate note: G1 PASS emitted per-node; no code written in this session (extraction only), so G2–G5 not applicable.

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/ShowcaseFeedView.swift — vertical feed skeleton: ScrollView + VStack(spacing:32), Color.black bg, .padding(.bottom,120), navigationDestination wiring
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/Generator.swift — «Моя Волна» orb as looped shader VIDEO via AVPlayerLayer + ShaderPlayerManager; direct candidate for my-vibe card (2004:10733)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift — remote cover loading/caching for API-driven covers
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/LowerHazeGrainOverlay.swift — grain/noise overlay, analog of Figma shader-noise rect 2004:10736 (color-dodge 0.7)
- /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur (Swift package) — progressive blur for tabbar/navbar underlay gradients (Figma uses 16-stop eased black gradient 210pt tall)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift, TopNavBar.swift, NavBar.swift — glass bar patterns (backdrop blur + white10 + hairline border)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/AnimatedIconButton.swift, PlayPauseButton.swift — circular glass icon buttons ≈ 40pt like/dismiss spec
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/Gyro3DTilt.swift + GyroManager.swift — gyro tilt, could drive the card rotations (-5…+5°) live
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/HeartExplosionView.swift — like-tap feedback animation
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/FontManager.swift + YangoText-Medium.ttf — YS Text Medium stand-in already bundled; need a YS Display Bold equivalent added
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Colors.swift — token extension pattern (add plusSolidOne #D88DFC, buttonsPrimary white10, buttonsSecondary white8, fillSix white40)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Shaders/ — Metal shader infra (MetalUtils, ShaderButtonView) for noise/glow if Generator video not reused
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayerV2.swift — collapsible mini-player matching action-bar 60×60 round player (2004:10784)

## OPEN QUESTIONS
- Like/dismiss behavior: does tapping ❤/✕ animate the card out of the feed (collapse/slide), and does the feed then pull up the next card? Any swipe gesture equivalent?
- Is the «Моя Волна» orb animated (reuse Generator.swift looped shader video) or a static composition of glow+glyph+noise for this prototype?
- Card tilts (-5…+5°, book -9.5°): static, or gyro/scroll-driven (Gyro3DTilt)?
- Search placeholder «Хочу послушать/почитать/посмотреть...»: rotating animation timing/easing, and does tapping open a query screen or Алиса?
- Continue-watching: should the video frame actually play (looped muted clip) or stay a still? Does the Rate answer dismiss the card / trigger a toast?
- Continue-reading: does tap open a reader screen at 36%? Is «Осталось 2 дня 5 часов» a rental-expiry countdown (live) or static copy?
- Should the main blurred background be generated at runtime from the visible cards' covers (and cross-fade while scrolling) or shipped as one static collage PNG?
- Feed composition: fixed 6-card sequence as in Figma, or template-driven (mock JSON) with alternating left/right layout rule and rotation-sign alternation?
- Which free public APIs to bind per card (TMDB for movies, Deezer/iTunes for album, Google Books/OpenLibrary for books), or fully mock data for screen 1?
- Tabbar: are the 5 tabs functional navigation targets in the prototype, or decoration with only Плюс active?