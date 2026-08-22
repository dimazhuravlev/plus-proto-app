# Figma spec: ACTION BAR + SEARCH (file 0HzFEKtm9oYdkksrDg7U14)

## 0. Source nodes
- Component set "action bar" 2001:111005 (frame 434x319 @ 521,230). Variants each 400x60: `state=search` 2001:111006, `state=music player` 2001:111009, `state=book player` 2001:111012, `state=movie player` 2001:111016 (h=60.007 — rotated-chip AABB).
- Component set "search" 2001:110986 (frame 318x294 @ 153,230). Variants each 284x60: `Property 1=Default` 2001:110987, `Variant4` 2001:110993, `Variant3` 2001:110999.
- Note: action-bar set has NO Code Connect mappings (server prompted to create them; skipped — non-interactive session).

## 1. Shared material (identical on every pill/chip in both sets)
- Fill: `rgba(255,255,255,0.10)` (#FFFFFF 10%, raw hex, no variable).
- Backdrop blur: Figma style **"BG Blur/System/iOS Specific" = BACKGROUND_BLUR radius 70** (CSS emits backdrop-blur 35px = radius/2).
- Border: **0.66px** solid, variable **Fill/Nine = #FFFFFF14** (white 8%).
- All pills `overflow: clip`.
- Variable **System/iOS Navbar darkBlur = #141414B2** is referenced in the 2001:111005 subtree (likely the frame bg); MusicPlayer's production mini-player uses exactly this as base coat (#141414 @ 0.72) under .ultraThinMaterial — see reuse below.

## 2. Variables / tokens (get_variable_defs on 2001:111005)
| Variable | Value |
|---|---|
| Fill/One | #FFFFFF |
| Fill/Subtitle | #FFFFFF80 (white 50%) |
| Fill/Nine | #FFFFFF14 (white 8%) — borders |
| Fill/Ten | #FFFFFF0F (white 6%) — progress overlay |
| System/iOS Navbar darkBlur | #141414B2 |
| BG Blur/System/iOS Specific | BACKGROUND_BLUR radius 70 |
| Text S・13/Medium | family "Yango Text", Medium, 13px / lh 16, ls 0, weight 500 |
- Placeholder color is raw `rgba(255,255,255,0.3)` (#FFFFFF4D) — not tokenized.

## 3. SEARCH component (2001:110986) — pill anatomy
Pill 284x60, corner radius **32** (clamps to 30 at h=60 → effectively a Capsule), padding H **18** / V **8**, HStack gap **8**, items center.
Children:
1. `icon / search` instance 24x24 (node 2001:110988 in Default). Inner vector leaf inset T7.92% R6.61% B6.61% L7.91% → glyph ~20.5x20.5 at (1.9,1.9). Monochrome SVG.
2. `titles` — ABSOLUTE-positioned VStack at **left 49.34px** (≈ 18 pad + 24 icon + 8 gap), column gap **16**, font **"YS Display" Bold 20px / line-height 26px**, color #FFFFFF4D. Contains all 3 placeholder rows stacked:
   - row1 "Хочу послушать..." — row2 "Хочу почитать..." — row3 "Хочу посмотреть..."
   - Variant mechanic = vertical ticker: container top = **16.34 / -25.66 / -67.66** for Default/Variant4/Variant3, i.e. steps of **42px = 26 lh + 16 gap**; non-active rows opacity 0.
   - Default→"послушать", Variant4→"почитать", Variant3→"посмотреть".

## 4. ACTION BAR — per-state spec
Container all states: width 400, padding H **24** (content box 352), HStack gap **8**, justify center, height 60.
- search & music: items-start + overflow-clip; book: fixed h-60 items-center **no clip** (rotated chip AABB 62.92 overflows ±1.46pt); movie: items-center + clip, h 60.007.

### state=search (2001:111006)
- [SearchPill fixed **284w** (instance of search/Default, placeholder "Хочу послушать..." visible)] + gap 8 + [mini-player button 2001:111008 fixed **60w**]. 284+8+60=352 ✓.
- Mini-player collapsed: "player" pill h 60, w 60, radius 32 (circle), same material; padding **pl 6 / pr 18 / pv 8**; content clipped at 60w → only the **48x48 circular cover** shows (x=6, 6px margins). Cover: radius 1000 (Circle), border 0.66 Fill/Nine, image aspect 480x480.
- Hidden inside (opacity 0, present for morph): track name block, actions row, progress overlay.

### state=music player (2001:111009)
- [Search button 2001:111010: icon-only pill, px 18 + 24 icon + gap → intrinsic **60x60 circle**, radius 32, placeholder titles opacity 0] + [mini-player 2001:111011 **flex-1 = 284w**].
- Mini-player expanded, structure (HStack gap **12**):
  - track info (gap **8**): 48x48 circular cover (as above) + track name column: title **"Strawberry Line"** — Yango Text Medium 13/16, Fill/One white; artist **"Cocteau Twins"** — 13/16, Fill/Subtitle #FFFFFF80.
  - actions (gap **18**, trailing): `icon / love` 24x24 (leaf inset 15.05%/8.33%/10.88%/8.33% → ~20.0x17.8), `icon / pause` 24x24 (leaf inset V 15.63% H 21.88% → ~13.5x16.5). White glyphs.
  - progress: absolute overlay, left/top/bottom **-0.66** (covers border), **width 130 fixed in mock**, fill **Fill/Ten #FFFFFF0F**, visible.

### state=book player (2001:111012)
- [SearchPill **flex-1 ≈ 295.9w**, placeholder "Хочу послушать..." visible] + [book chip wrapper 48.078x62.923 = AABB of 44x60 rotated **4°** (clockwise)].
- Book chip: **44x60, radius 4**, same material, centered content = book cover image **36x52** (node 2001:111015; mock: Дэвид Гребер «Бредовая работа», Ad Marginem, green). 352-8-48.078 ≈ 295.9 ✓.

### state=movie player (2001:111016)
- [SearchPill **flex-1 ≈ 252.4w**] + [movie chip wrapper 91.552x60.007 = AABB of 88x54 rotated **4°**].
- Movie chip: **88x54, radius 8, inner padding 4**, same material; inner frame flex-1 full-height (**80x46**) **radius 4**, image fill cover (node 2001:111019; mock: landscape film still).

### Differences matrix (the 4 states)
| | search | music | book | movie |
|---|---|---|---|---|
| search pill w | 284 fixed | 60 (icon-only) | flex ≈295.9 | flex ≈252.4 |
| placeholder | visible | opacity 0 | visible | visible |
| right element | mini-player 60w (cover only) | mini-player 284w full | book chip 44x60 r4 rot4° | movie chip 88x54 r8 rot4° |
| track text/actions | opacity 0 | visible | — | — |
| progress overlay | opacity 0 | visible (w130) | — | — |
| container | items-start, clip | items-start, clip | items-center, NO clip, h60 | items-center, clip, h60.007 |

## 5. Typography
- Placeholder: **YS Display Bold 20 / 26**, #FFFFFF4D. NOT in MusicPlayer (it bundles YangoGroupHeadlineAR-ExtraBold + YangoText); YS Display font file needed or substitute.
- Track title/artist: **Yango Text Medium 13 / 16** = existing `.Text2` token (CustomFonts.swift:20 `Font.custom("YangoText-Medium", size: 13)`).

## 6. Assets to export (remote URLs expire ~7 days from 2026-08-22; export by node ID instead for committed code)
| Asset | Node ID | Size (outer / leaf) | Mock URL |
|---|---|---|---|
| icon/search SVG (template) | 2001:110988 (inst. in 2001:110987) | 24x24 / ~20.5x20.5 inset 7.92/6.61/6.61/7.91% | .../asset/fba2488a-fe20-446b-8b7f-1a00ea49a65d.svg |
| icon/love SVG | I2001:111008;2127:128 (vector ;19:3848) | 24x24 / 20.0x17.8 | .../asset/69e03205-07eb-4932-bbf1-11938987f5cc.svg |
| icon/pause SVG | I2001:111008;742:44123 (vector ;19:2276) | 24x24 / 13.5x16.5 | .../asset/22326280-9ee6-4b28-8e88-56ba05565a09.svg |
| album cover (mock content) | I2001:111008;741:54325;558:1689 | 480x480 → shown 48x48 circle | .../asset/5f6bc441-208b-4987-919d-f0b51b1e6f5e.png |
| book cover (mock) | 2001:111015 | 36x52 | .../asset/e1fa8868-6071-4166-a35e-fb0bb3e0f870.png |
| movie still (mock) | 2001:111019 | 80x46 shown, r4 | .../asset/eec0c501-4f85-4737-8f68-e0006f34c3f7.png |
Base URL prefix: https://www.figma.com/api/mcp/asset/. MusicPlayer asset catalog already has "search", "like-default", "pause" template icons (used in BottomBarV2.swift:366/365-379, MiniPlayerV2.swift:65,72) — verify glyphs against exported SVGs before reusing; likely identical family.
The 3 content images are mock — in the prototype they come from APIs/mock data, not bundled.

## 7. SwiftUI mapping sketch
```swift
enum ActionBarState { case search, musicPlayer, bookPlayer, moviePlayer }

// ActionBar.swift
HStack(spacing: 8) {           // .padding(.horizontal, 24), height 60
  SearchPill(state:)           // width: 284 fixed | 60 icon-only | nil (flex) — animate .frame(width:)
  trailingElement(state:)      // MiniPlayerPill | BookChip | MovieChip
}

// Shared material (one modifier, reuse MiniPlayerV2 pattern):
struct GlassPill: ViewModifier { // Capsule or RoundedRectangle(r, style: .continuous)
  ZStack { Color(hex: 0x141414).opacity(0.72); Rectangle().fill(.ultraThinMaterial); Color.white.opacity(0.10) }
  .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.66))
  .clipShape(shape)
}

// SearchPill: HStack(spacing: 8){ Image("search") 24x24; PlaceholderTicker() }
//   .padding(.horizontal, 18) — Capsule material
// PlaceholderTicker: VStack(spacing:16){ 3 x Text(.custom("YSDisplay-Bold", 20)) }
//   .offset(y: -42 * index).opacity per row — clipped; anchored 49.34pt from leading

// MiniPlayerPill ≈ copy of MusicPlayer/Features/MiniPlayerV2.swift with:
//   collapsed: .frame(width: 60) + text/actions/progress opacity 0 (keep in tree)
//   expanded:  flex width, HStack(12){ cover48 circle; VStack titles .Text2; HStack(18){ love; pause } }
//   .padding(.leading, 6).padding(.trailing, 18); progress = leading overlay width w*progress (Fill/Ten)

// BookChip: RoundedRectangle(4) material 44x60 { Image book 36x52 } .rotationEffect(.degrees(4))
// MovieChip: RoundedRectangle(8) material 88x54, padding 4 { Image .clipShape(RoundedRectangle(4)) } .rotationEffect(.degrees(4))
```

## 8. Morph animation — what must interpolate between states
1. **Widths** (single HStack, animate frame widths; spring `.smooth`): search pill 284 ↔ 60 ↔ flex; trailing element 60 ↔ 284 ↔ 48.08 ↔ 91.55. Keep both views alive; do NOT if/else-swap the search pill (kills continuity) — the Figma structure deliberately keeps hidden layers at opacity 0 for this.
2. **Opacity crossfades**: placeholder titles 1↔0 (music); track title/artist 0↔1; actions row 0↔1; progress 0↔1.
3. **Placeholder ticker**: vertical offset 0 / -42 / -84 in 42pt steps (26 lh + 16 gap) + per-row opacity — this is the search-set variant carousel.
4. **Corner radius**: pills constant 32/Capsule; chips 4 (book) / 8 (movie) — if morphing pill↔chip, interpolate radius 32→4/8 and rotation 0→4°.
5. **Rotation**: 0 ↔ 4° on book/movie chip (wrapper AABB grows to 48.08x62.92 / 91.55x60.01 — book overflows the 60pt bar by 1.46pt each side, unclipped).
6. **Chip height**: movie tile 54 vs bar 60 (centered); book tile 60.
7. **Mini-player reveal**: fixed width 60 with overflow clip over content laid out at full width (pl6+48+…+pr18) — expanding width naturally reveals text/actions from under the clip; cover stays anchored 6pt from leading.
8. Material constant across all states → morph reads as one continuous glass surface; matchedGeometryEffect only needed if views must swap identity, otherwise animate constants on persistent views (the MusicPlayer BottomBarV2 pattern: progress-driven CGFloat interpolation, `.animation(_, value:)` per property).

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayerV2.swift — near-exact Figma mini-player match: 48pt circular cover, HStack 12/18, pl6/pr18, 0.66pt white-8% stroke, progress fill white-6% width*progress (line 30), #141414@0.72 + .ultraThinMaterial glass (lines 22-31), rotating cover via TimelineView (18°/s)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift — bottom-chrome composition pattern: safe-area-anchored ZStack in GeometryReader, progress-driven CGFloat interpolation with per-property .animation(_, value:), VariableBlur chrome background (lines 394-418), press-scale 0.92 gesture, UIImpactFeedbackGenerator haptics
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Colors.swift — Color.fill1 (=Fill/One), Color.subtitle (=Fill/Subtitle #ffffff80); extend with fill9 white 8% and fill10 white 6% for borders/progress
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/CustomFonts.swift — Font.Text2 = YangoText-Medium 13 == Figma token Text S・13/Medium (track title/artist); YS Display Bold 20 for the placeholder is NOT bundled — add font or substitute
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift — remote artwork loading with asset fallback, used by mini-player cover
- /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur (local Swift package) — gradient blur for bottom chrome behind the action bar
- MusicPlayer asset catalog template icons "search", "like-default", "pause" (referenced in MiniPlayerV2.swift:65,72 and BottomBarV2.swift:366) — likely the same glyph family as Figma nodes 2001:110988 / I2001:111008;2127:128 / I2001:111008;742:44123; verify against exported SVGs
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/PlayPauseButton.swift and AnimatedIconButton.swift — icon button press/toggle animations for the actions row

## OPEN QUESTIONS
- Placeholder ticker logic: do the 3 placeholders (послушать/почитать/посмотреть) auto-rotate on a timer, or does the variant follow the active vertical (music/books/movies)? What interval/easing for the 42pt scroll step?
- State machine: what triggers each of the 4 states (playback start per vertical?), and does tapping the collapsed 60pt search circle in music state morph back — collapsing the mini-player to the 60pt cover-only pill?
- Progress overlay is a fixed 130pt rectangle in the mock — confirm it should be real playback progress (width = pillWidth * fraction, as in MusicPlayer MiniPlayerV2:30).
- Book/movie chips have no controls (no pause/like) — what does tapping the chip do (open full-screen reader/player)? Should book/audiobook show progress anywhere?
- Is the 4° chip rotation static, or animated on appear (e.g. spring wobble from 0°)?
- Search state's mini-player shows only a cover: is it visible even when nothing has ever played (empty/hidden state?), and does the cover rotate like MusicPlayer's (18°/s)?
- YS Display Bold for the placeholder: can the font file be bundled in the prototype, or substitute (YangoGroupHeadline / SF Pro Rounded)?
- Morph implementation preference: one persistent HStack with animated width/opacity constants (Figma structure supports it — hidden layers kept at opacity 0) vs matchedGeometryEffect across separate state views?