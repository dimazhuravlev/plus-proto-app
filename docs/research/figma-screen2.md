# SHOWCASE SCREEN 2 — «Полчаса в такси…» (contextual short feed) — Figma spec

File `0HzFEKtm9oYdkksrDg7U14`, frame `2004:10785` "screen", 402×1138, bg #000, corner radius 40 (device frame), overflow clip. All coords below are absolute in frame space unless noted. Figma vars used on this node: `Plus/Solid One=#D88DFC`, `Fill/One=#FFFFFF`, `Fill/Six=#FFFFFF66` (white 40%), `Fill/Nine=#FFFFFF14` (white 8%), `Buttons/Primary=#FFFFFF1A` (white 10%), `Font/Font Size/11=11`, `Font/Line Height/14=14`, `System/iOS Navbar darkBlur=#141414B2`, `BG Blur/System/iOS Specific=BACKGROUND_BLUR r70`.

## 1. Background (warm/red — vs screen 1 green/dark)
- `2004:10786` "blurred bg": rounded-rect 776×2113 at (-187, -127) — massively oversized so 100px blur doesn't fade at edges. Layer blur 100px; image fill opacity 40% over black; scaleToFill.
- **Source image identified**: it is a warm gold/red movie poster ("Faqret El Saher", Yango Original; PNG 292×438, asset `126aad93-571f-49ca-9f6e-15c8d68674be.png`). NOT the Twin Peaks still. So the warm palette is content-derived in spirit (matches the red ТВИН ПИКС logo) but the actual fill is a separate poster asset. For the app: generate bg by blurring the hero content artwork (blur 100, opacity 0.4 over black) — same construction as screen 1, only the source image differs.

## 2. Two-tone headline `2004:10787`
- Frame: x24, y72, w354, h108 (3 lines). Font **YS Display Bold 32/36, tracking -0.2px**.
- Construction: single paragraph, background-clip:text with linear gradient **to-left: right stop rgba(255,163,163,0.6) (#FFA3A3 @60%) → left stop #9E8E8E**; span 1 «Полчаса в такси.» overridden to solid **#FFFFFF**; span 2 « Одна серия или послушаем несколько песен?» transparent → shows the pink/warm gradient.
- vs screen 1: identical structure (white lead sentence + tinted question), only the accent gradient hue differs (pink/red here) — accent tint appears to be per-context/content-derived.

## 3. Video card group `2004:10788` (Твин Пикс)
Whole card **rotated -5°**; unrotated size 277×156, r12; rotated bounding box 289.54×179.55 at (-7.27, 207) — bleeds 7.27px off the left screen edge.
- Glow `2004:10789` "ambilight bg": same 277×156 r12 rect at same position/rotation, **layer blur 28px, fill opacity 50%**, drawn UNDER the card. NOTE: its image fill is a *different* film still (kitchen scene, «Лето»-like, 3204×1390, asset `f72ae549`) — not the Twin Peaks frame (see open question).
- Card `2004:10790` "video frame": 277×156, r12, border 0.66px rgba(255,255,255,0.08), clip. Fill = Twin Peaks funeral still (745×440, asset `e638d9a8`), scaledToFill. Content column bottom-aligned: padding 8 (sides/bottom), gap 2.
  - Bottom scrim `2004:10791` "overlay bg": 277×35 anchored to bottom edge, gradient black 50% at bottom → transparent at top (a top-gradient rotated 180°).
  - Label `2004:10792` «Осталось 28 мин»: YS Text Medium 13/16, tracking -0.2, white.
  - Timeline `2004:10793`: track `2004:10794` 261×6, r8, bg rgba(255,255,255,0.1), backdrop-blur 6; fill `2004:10795` 34.75×6, r8, color `Plus/Solid One` **#D88DFC** → progress ≈ **13.3%**.
- Close button `2004:10796`: instance of component **11:9189 «Size=md • 40px, Type=primary, Icon=only, State=default»** ("Второстепенная кнопка"). 40×40 circle (r1000), padding 10, icon 20×20 (X glyph inset 17.3% ⇒ ~13.1px), bg `Buttons/Primary` rgba(255,255,255,0.1), border 0.66px rgba(255,255,255,0.06), **backdrop blur 20**. Positioned at (13, 208.93), **NOT rotated** — floats over the tilted card's top-left corner.
- Twin Peaks logo `2004:10806` "Orig 640x129 1": raster PNG (640×129 native, asset `757c23e3`, red «ТВИН ПИКС» title art) placed 174×35 at (215, 334). **No rotation** (despite being briefed as "rotated label"). Overlaps the card's bottom-right corner and extends past the card's right edge onto the background; sits ABOVE the album group in z-order list but visually over the video card.

## 4. Album card group `2004:10797` (Tame Impala — Currents)
- Cover `2004:10799`: 180×180, r12, **rotated +2°**, border **1px** rgba(255,255,255,0.08) (note: 1px here vs 0.66px on video card), fill = Currents cover (638×608, asset `fec6aad8`). Rotated bounding 186.17², top 430, centered at x = screenCenter+34.59 ⇒ cx≈235.6 (metadata alt reading ≈241.9 — ±6px ambiguity, use code value 235.6).
- Glow `2004:10798` "ambilight bg": identical rect/rotation underneath, layer blur 28, **fill opacity 70%** (vs 50% for video, 30% for book — glow strength varies per card).
- Text `2004:10803` at (53, 462), w86, right-aligned, to the LEFT of the cover: «Tame Impala» YS Text Medium 15/18 tracking -0.2 white; «Currents» same at 50% opacity.
- Buttons `2004:10800` at (151.68, 596), row gap 6, total 86×40, below-left of cover: heart button `2004:10801` (icon inset 15.05%/8.33%/10.88%/8.33%, asset `05a9f1d7`) + close button `2004:10802` (same X icon `d49eb834`) — both instances of the same 11:9189 component with identical material (blur 20, white 10%, border 0.66 white 6%).

## 5. Book card group `2004:10807` (Технофеодализм) — isometric construction
Group at (15, 659.95), 415.55×283.31 — **bleeds off the right screen edge** (extends to x≈430.5 > 402).
- `2004:10808` "isometric book" (232×283.31 bounding, top-right zone, cx≈314.2 = screenCenter+113.17):
  - Front cover `2004:10811` «Технофеодализм 1»: 157.86×226.09, **rotate -9.47°, skewX 0.36°**, fill = book cover (1200×1719, cyan Varoufakis «Технофеодализм», ad marginem; asset `3265e0d0`), bounding 194.32×248.75 at top 671.65.
  - Glow `2004:10809` "ambilight bg": same image, 157.98×226.31, rotate -9.46°, skewX 0.39°, **blur 28, opacity 30%**.
  - Spine paper strip `2004:10813`: image 10.19×226.1 (asset `3cfa3b82`, 11×227 native), **rotate -9.84°**, at (216.97, 695.89), bounding 48.68×224.51.
  - Pages-edge SVG `2004:10812` "Vector 234255887": 39.65×230.9 at (216, 697.6) (asset `fcd9d222`).
  - Floor shadow SVG `2004:10810` "Vector 234255888": 157.35×34.1 at (254, 894.4); exported SVG has baked blur bleed (renders with inset -11.73% top / -5.08% x / -35.19% bottom) (asset `c8abeff2`).
- Annotation `2004:10814` at (15, 758), w192, column gap 8, right-aligned:
  - Text `2004:10815`: «Что пришло на смену капитализму и как это изменило мир? Новый взгляд на экономику», YS Text Medium 15/18 tracking -0.2, **gradient text**: linear -90° (to left): right stop **#BCEBFB** (light cyan, matches book cover) → left stop #FFFFFF. Another instance of content-derived tinting.
  - Buttons `2004:10816` (heart `2004:10817` + close `2004:10818`, same 11:9189 component) at abs (121, 838), gap 6.

## 6. Tabbar instance `2004:10819` (0, 1038, 402×100)
Same tabbar component as screen 1 (internal component nodes 2004:9137 "underlay gradient", 2004:9138 "tabs", icon component 2004:9381; instance children I2004:10819;2004:9396/9406/9420/9427).
- **Active tab here = «Плюс»** (screen-level difference; screen 1 presumably had a different active tab). Active: purple pulse glow SVG behind symbol (asset `a7168f16`, drawn in a 50×43 box at bottom 11, rotated 180°, with huge bleed inset -130.23%/-112% ⇒ actual glow ~3.6× the box), symbol tile border 0.733px white 6%, label `Fill/One` white. Inactive tabs (Музыка/Кинопоиск/Книги/Алиса): faint pulse asset `5d9a9c35` at bottom 7, tile border 0.66px white 4%, label `Fill/Six` white 40%.
- Tab tile: 40×40, r14, bg rgba(255,255,255,0.1); label 11/14 «Yandex Sans Text Medium», gap 2; each tab 60×62; row: pt4 px24 justify-between.
- Underlay gradient: 210px tall band anchored top -110 (spans y 928–1138): linear, black 0.9 at bottom → transparent at top, 16 eased stops (0.9/0.867/0.828/0.783/0.732/0.678/0.619/0.556/0.491/0.424/0.354/0.284/0.212/0.141/0.07/0 at 0/11.23/20.5/28.12/34.39/39.6/44.06/48.07/51.93/55.94/60.4/65.61/71.88/79.5/88.77/100%).
- Home indicator: 134×5, r100, white, in 34px container (pt21 pb8).
- Tab icons (SVG assets): Плюс `5ed910ff` (inset 15.63%), Музыка `1492e446` (Union, inset 9.38%), Кинопоиск `cf4db65e` (NNEEWW, 28.75px, offset x+5.62), Книги `4311e448` (28.75×32.5, offset x-5.62 y+3.75), Алиса `f3613241` (Exclude, 26.25×25.3).

## 7. Action bar instance `2004:10820` (0, 973.99, 402×60), bottom-104
Component children 2001:111017 "search" + 2001:111018 "movie player". Row: px24, gap 8, centered.
- Search pill: flex-1 (≈262×60), r32, bg rgba(255,255,255,0.1), **backdrop blur 35**, border 0.66px `Fill/Nine` #FFFFFF14, px18 py8. Search icon 24 (asset `9accc728`). Placeholder stack at (49.34, 16.34) local: 3 lines YS Display Bold 20/26, rgba(255,255,255,0.3): **«Хочу послушать...» visible; «Хочу почитать...» and «Хочу посмотреть...» opacity 0** ⇒ rotating-placeholder animation is designed in (screen-level: screen 2 shows the «послушать» phrase).
- Mini "movie player": 88×54, r8, **rotate +4°** (bounding 91.55×60), same material (blur 35, white 10%, border 0.66 Fill/Nine), inner padding 4, thumb r4 fills rest. Thumb fill = the SAME kitchen film still `f72ae549` used by the video card's ambilight — i.e. a "continue watching" mini-player docked next to search.

## 8. Navbar `2004:10821` (0, -1, 402×160)
- `2004:10822` "overlay bg": 402×72 top scrim, linear black 50% → transparent, backdrop-blur 0.
- Status bar instance `2004:10823` (component 230:56586): h54, px32 pt17 pb13; time «19:25» SF Pro Text Semibold 17/17, tracking -0.5, ss03; right cluster cellular 19.97×12 / wifi 17×12.5 / battery 27.33×13 (assets `9c2a11e3`/`8156ff17`/`9bb739c6`).

## 9. Component reuse confirmation (vs screen 1)
- The content cards (video frame, album cover, isometric book) are **NOT component instances** — plain frames/groups hand-placed per screen (metadata types: frame / rounded-rectangle / vector). Reuse across screens is by copy, not by component.
- Actual instances on this screen: circular icon buttons → component **11:9189** (all 5: close ×3, heart ×2); tabbar → same master as screen 1 (children 2004:91xx); action bar → master children 2001:111017/111018; status-bar → 230:56586; home-indicator → 4:26673. So screen-to-screen the chrome (tabbar/action bar/navbar/buttons) is componentized; the feed cards are bespoke arrangements of the same visual recipe: content image + same-image ambilight (blur 28, opacity 30–70%) + hairline border + slight rotation + circular buttons.
- Card recipe deltas vs screen 1 to encode as parameters: rotation (-5° / +2° / -9.5°+skew), glow opacity (0.5 / 0.7 / 0.3), border width (0.66 / 1 / n-a), corner radius 12, edge bleed (video off left, book off right).

## 10. Assets to export (node IDs; MCP URLs expire ~7 days; local copies saved to /tmp: s2_blurredbg.png, s2_twinpeaks_logo.png, s2_videoframe.png, s2_ambilight_video.png, s2_album.png, s2_book.png, s2_spine.png)
- `2004:10786` bg poster fill (Faqret El Saher, 292×438) — or skip and derive bg by blurring content
- `2004:10790` fill: Twin Peaks still 745×440
- `2004:10789` / mini-player fill: kitchen film still 3204×1390
- `2004:10806` Twin Peaks logo PNG 640×129
- `2004:10799` fill: Currents cover 638×608
- `2004:10811` fill: Технофеодализм cover 1200×1719; `2004:10813` spine strip 11×227
- `2004:10812` pages SVG; `2004:10810` shadow SVG — OR export whole `2004:10808` "isometric book" as one PNG (recommended for prototype)
- Icons: X `19:6160`, heart `19:3851`, search `19:389`; tab icons `2004:9357` (Плюс), `2004:9180` (Музыка), `2004:9176` (Кинопоиск), `2004:9184` (Книги), `2004:9268` (Алиса); pulse glows (active `a7168f16` w/ bleed, inactive `5d9a9c35`)

## 11. SwiftUI mapping sketch (reusing MusicPlayer patterns)
- Screen = ZStack: Color.black → oversized blurred content image (`.scaledToFill().frame(width: 776, height: 2113).blur(radius: 100).opacity(0.4)` — cf. MusicPlayer's OfflineGlowBackground.swift approach) → scrollable/static card layer → top scrim + status bar → action bar → tabbar.
- Headline: SwiftUI can't clip one gradient across part of a concatenated Text easily; options: (a) two Texts in a wrapping layout, (b) whole-paragraph LinearGradient mask with a white overlay Text for the lead sentence, (c) approximate accent with solid #E39A9A. Decide in implementation; keep accent tint as a per-screen token.
- Card recipe → one `AmbilightCard` view: `content.rotationEffect(.degrees(angle))` with `content.blur(28).opacity(glow)` behind; hairline `.strokeBorder(.white.opacity(0.08), lineWidth: 0.66)`; params (rotation, glowOpacity, borderWidth). Video variant adds bottom scrim + label + Capsule progress (261×6 track white 10%, fill #D88DFC, 13.3%).
- Circular button → small component: Circle 40, `.background(.white.opacity(0.1))` + custom backdrop blur (VariableBlur package at /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur is available for gradient/backdrop blur), stroke 0.66 white 0.06, 20pt icon.
- Isometric book: for the prototype export `2004:10808` as a flattened PNG (+separate cover image if content must be dynamic); rebuilding with rotation3DEffect/skew is possible (rotate -9.47° + skewX 0.36° ≈ projection) but low ROI.
- Tabbar/action bar: shared components across all showcase screens; model after MusicPlayer BottomBarV2.swift + MiniPlayerV2.swift; underlay gradient = LinearGradient with eased stops (or VariableBlur).
- Images: MusicPlayer/Features/CachedAsyncImage.swift for remote artwork; fonts — MusicPlayer only bundles YangoGroupHeadlineAR-ExtraBold.otf and YangoText-Medium.ttf (MusicPlayer/MusicPlayer/Fonts/): **YS Display Bold, YS Text Medium/Regular, Yandex Sans Text Medium are NOT in the repo and must be added** (or substituted with SF/Yango).


## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift — remote artwork loading for card covers/posters
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/OfflineGlowBackground.swift — blurred-image glow background pattern (matches ambilight/blurred-bg construction)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift and BottomBar.swift — tab bar with underlay gradient pattern
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayerV2.swift — docked mini-player pattern for the action-bar movie thumb
- /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur (Swift package) — gradient/backdrop blur for tabbar underlay and glass buttons
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/ShowcaseFeedView.swift and ForYouShowcase.swift — showcase screen composition pattern
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/FontManager.swift + CustomFonts.swift — custom font registration (YS Display/YS Text/Yandex Sans Text must be added; only Yango fonts bundled now)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Colors.swift — token pattern for Fill/One..Nine, Buttons/Primary, Plus/Solid One (#D88DFC)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/AnimatedIconButton.swift — base for the 40pt glass icon buttons (component 11:9189)

## OPEN QUESTIONS
- The video card's ambilight glow AND the action-bar mini-player both use a different film still (kitchen scene, «Лето»-like) than the card's Twin Peaks frame — is the mini-player intentionally a second in-progress movie, and should the card glow be derived from the card's own frame in the app?
- Search placeholder has 3 stacked phrases («Хочу послушать/почитать/посмотреть...») with 2 at opacity 0 — is a cycling animation intended, and with what cadence/transition?
- Headline accent gradient (pink #FFA3A3→#9E8E8E here, green on screen 1) and book annotation tint (#BCEBFB from cover) look content-derived — should tints be computed from dominant artwork colors at runtime or hardcoded per screen?
- What does the X (close) button on each card do — dismiss the card with feed reflow, mark 'not interested', or dismiss the whole contextual feed?
- Is the feed static (one fixed 1138pt canvas) or scrollable, and are card entrance animations / parallax / gyro tilt expected?
- Should the isometric book be a flattened exported PNG (fast) or rebuilt in SwiftUI with skew/rotation so any book cover can be injected dynamically?
- Progress «Осталось 28 мин» / 13.3% — live-updating from mock playback state or static?