# TABBAR spec — Figma 0HzFEKtm9oYdkksrDg7U14

## 1. Node map
- `2004:9169` **tabbar** symbol, 375×100. Children: `2004:9137` underlay gradient (375×210, y=-110 rel. to tabbar top), `2004:9138` tabs row, `4:26673`→`4:26674`→`4:26675` home-indicator.
- `2004:9385` **"icon"** component set (full tab button, 60×62): `2004:9381` state=inactive, `2004:9386` state=active.
- `2004:9170` **"service icon"** component set (glyph tile content, 32×32 native, 10 variants):
  - Kinopoisk: inactive `2004:9175` (glyph node `2004:9176` "NNEEWW"), active `2004:9177` (glyph `2004:9178`)
  - Music: inactive `2004:9179` (glyph `2004:9180` "Union"), active `2004:9181` (glyph `2004:9182`)
  - Books: inactive `2004:9183` (glyph `2004:9184` "Vector"), active `2004:9185` (glyph `2004:9186`)
  - Alisa: inactive `2004:9266` (glyph `2004:9268` "Exclude"), active `2004:9276` (glyph `2004:9277`)
  - Plus: inactive `2004:9281` (glyph `2004:9303` "PLUS-SYMBOL"), active `2004:9356` (glyph `2004:9357`)

## 2. Layout (exact px)
- Tabbar frame: 375×100, vertical stack: tabs row (66 = 62 content + 4 padding-top) + home-indicator (34).
- Tabs row `2004:9138`: padding-top 4, padding-h 24, `justify-between` → 5 buttons 60×62 each; computed inter-button gap = (375−48−300)/4 = **6.75**.
- Tab order in master (L→R): Плюс (active in master), Музыка, Кинопоиск, Книги, Алиса.
- Tab button (icon component, 60×62): VStack, gap **2**, centered: [tile 40×40] + [label line-height 14] = 56 total, centered vertically in 62.
- Tile ("symbol" node): 40×40, corner radius **14**, fill `rgba(255,255,255,0.10)` both states; border: inactive `rgba(255,255,255,0.04)` @ 0.66px, active `rgba(255,255,255,0.06)` @ 0.733px; clips content.
- Glyph inside tile: the 32×32 "service icon" instance is scaled ×1.25 to 40×40. Native 32-frame glyph geometry (leaf size @ optical offset from center):
  - Kinopoisk 23×23 @ (+4.5, 0)
  - Music 26×26 @ (0,0) (inset 9.38% = 3px each side)
  - Books 23×26 @ (−4.5, +3)
  - Alisa 21×20.239 @ (0, −0.4)
  - Plus 22×22 @ (0,0) (inset 15.63% = 5px each side)
  - At 40pt tile these offsets scale ×1.25 (e.g. Kinopoisk +5.62, Books −5.62/+3.75, Alisa 0/−0.5). **Export the full 32×32 variant frame per tab so offsets are baked in**, then render at 40×40.
- Home indicator `4:26674`: h 34, padding top 21 / bottom 8, bar 134×5, fill `Fill/One` #FFFFFF, radius 100, centered.

## 3. Variables (get_variable_defs)
- `Fill/One` = `#ffffff` (active label, home-indicator bar)
- `Fill/Six` = `#ffffff66` (white 40% — inactive label)
- `Font/Font Size/11` = 11; `Font/Line Height/14` = 14
- No variables bound on service-icon set (raw hex in fills).

## 4. Typography
- Label: font **"Yandex Sans Text" Medium**, size 11, line-height 14, center-aligned, word-break enabled. Active = #FFFFFF, inactive = white 40% (#ffffff66). Texts: Плюс / Музыка / Кинопоиск / Книги / Алиса.

## 5. Icon fills & effects (from exported SVGs, verified byte-level)
- **All 5 active glyphs share one linear gradient** (TL→BR diagonal): `#E269E1` @0 → `#893BBA` @0.4 → `#F1AFE0` @1.0, opacity 1.
- **All 5 inactive glyphs share**: linear gradient white 50% → white 25% (top-right → bottom-left-ish diagonal), whole path additionally `fill-opacity="0.7"`.
- All glyphs (both states) carry a 3-layer **white inner-shadow "glass emboss"** (values at 32-native scale, Figma radius = 2×SVG stdDeviation): (1) offset y+1.02, blur σ1.02, white 10%; (2) offset y−0.20, blur σ0.51, white 20%; (3) dilate/spread 3.07, offset y+0.51, no blur, white 10%. Subtle; can be baked into exported assets rather than reproduced.
- Icons are **pure vectors** (SVG paths, no rasters anywhere in the component). Pulse glow is also vector (blurred ellipse — reproduce natively, no asset needed).

## 6. Active-state glow ("pulse")
- Structure inside tab button: absolutely positioned container **50×43**, anchored bottom-center; `bottom = 7` when inactive, `bottom = 11` when active; container rotated **180°**.
- Shape: ellipse rx 25 / ry 21.5 (fills the 50×43 box) with **layer blur σ=28 (SVG stdDeviation; ≈ Figma blur 56)** — blurred bounds bleed to 162×155 (inset −130.23% v / −112% h).
- Fill: two stacked opaque radial gradients, identical geometry — effective visible one (top layer): center `#AC5387` → edge `#4C31BE`; underlying layer `#8D53AC` → `#6453AC`. Radial center offset from ellipse center: (−0.85, −15.44) pre-rotation → after 180° rotation the hotspot sits ~15.4px **below** ellipse center; radial extents ≈ 36.8 wide × 20.1 tall.
- **Inactive variant contains the identical pulse node with `opacity 0`** — designed for crossfade + 7→11px positional shift on activation.
- Verbal description (from screenshots `2004:9386`, tabbar master): a soft diffuse violet halo envelops the whole 40pt tile and bleeds ~1 tile-width outward; brightest as a warm pink-magenta (#AC5387-ish) hotspot at the tile's **bottom edge, spilling onto the label** ("Плюс"/"Кинопоиск" label renders white on top of a faint magenta wash); fades outward to cool indigo/violet and to nothing well before neighboring tabs. Glyph itself simultaneously switches from grey (white-alpha gradient) to the purple E269E1/893BBA/F1AFE0 gradient; tile keeps the same 10% white fill — the "lit" feel comes from the halo + glyph gradient, not the tile.

## 7. Background treatment (underlay)
- Node `2004:9137`: 375×210 positioned so its bottom aligns with tabbar bottom (top = −110 rel. tabbar → scrim extends 110px above the 100px tabbar).
- Fill: vertical linear gradient, black, bottom→top, 16 eased stops (bottom-first): 0%→a0.90, 11.23%→.867, 20.504%→.828, 28.123%→.783, 34.389%→.732, 39.601%→.678, 44.062%→.619, 48.071%→.556, 51.929%→.491, 55.938%→.424, 60.399%→.354, 65.611%→.284, 71.877%→.212, 79.496%→.141, 88.77%→.07, 100%→0 (smooth easing curve; reproduce stops verbatim in a SwiftUI LinearGradient).
- Also carries `backdrop-blur: 0px` — a blur layer present but set to 0 in Figma; intent is likely progressive blur (VariableBlur package already in MusicPlayer). No solid background: tabbar floats over content with scrim only.

## 8. Safe area
- The 34px home-indicator block is baked into the 100px frame (375×100 = non-notch width but home-indicator present → treat as design canvas convention). Implementation: place tabs row (66pt) above the bottom safe-area inset via `.safeAreaInset(edge: .bottom)` / `ignoresSafeArea` for the scrim; don't hardcode 34 — use geometry safe-area, min 8pt on devices without indicator. Scrim must extend under safe area to screen bottom edge.

## 9. Asset export plan
- Export as SVG→PDF/asset-catalog "Preserve Vector Data": the ten 32×32 variant frames `2004:9175/9177/9179/9181/9183/9185/9266/9276/9281/9356` (offsets baked). Alternative minimal set: 5 monochrome template glyph paths + programmatic gradient fill via `.mask` (loses inner shadows).
- Not needed as assets: pulse glow (native Ellipse+RadialGradient+blur), underlay gradient (native LinearGradient), home indicator (native Capsule), tile (native RoundedRectangle).
- Downloaded reference copies (7-day MCP URLs, local copies): `/tmp/figma_tabbar/*.svg` (kinopoisk/music/books/alisa/plus × active/inactive, pulse_active, pulse_inactive).

## 10. SwiftUI mapping sketch
```
TabBarView (ZStack, height 100 + bottomSafeArea)
├── UnderlayScrim: LinearGradient(16 stops above), frame h=210, aligned bottom, .allowsHitTesting(false), optional VariableBlur underlay
├── HStack(spacing: 0) { ForEach(tabs) TabButton }, .padding(.horizontal, 24), .padding(.top, 4), frame h=66 — use Spacer()s or .frame(maxWidth:.infinity) per button to reproduce justify-between (gap 6.75 @375)
└── HomeIndicator only if custom-drawn; otherwise let system render

TabButton (60×62)
├── background: PulseGlow — Ellipse().fill(RadialGradient(#AC5387→#4C31BE, center ~UnitPoint(x:0.48,y:0.86), radii 36.8×20.1)).frame(50,43).blur(radius:28).opacity(isActive ?1:0).offset(y: isActive ? -11+…: -7+…) anchored bottom; animate with .spring
├── VStack(spacing: 2)
│   ├── RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1)).strokeBorder(.white.opacity(isActive ?0.06:0.04), lineWidth: isActive ?0.733:0.66).frame(40,40)
│   │     .overlay(Image("tab_<name>_\(state)").resizable().frame(40,40)) // 32-native asset scaled ×1.25, clipped
│   └── Text(label).font(.custom("YandexSansText-Medium", size: 11)).lineSpacing→14pt lineHeight, .foregroundStyle(isActive ? .white : .white.opacity(0.4))
```
State model: `enum AppTab { case plus, music, kinopoisk, books, alisa }`, `@Binding activeTab`, crossfade glyph active/inactive assets + glow opacity/offset in one `withAnimation`.

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBarV2.swift — existing Figma-derived bottom chrome: tab row + press states + offline offsets; closest structural template for the new tabbar
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/BottomBar.swift and NavBar.swift/TopNavBar.swift — earlier bar patterns
- /Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur (local Swift package, imported in BottomBarV2) — progressive blur for the underlay scrim (Figma has backdrop-blur placeholder at 0)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Colors.swift — Color extension token pattern (fill1/fill5); new app needs fill1=#FFFFFF, fill6=white 40%
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/CustomFonts.swift — Font extension pattern (Text3 = custom 11pt matches label size); note MusicPlayer bundles YangoText-Medium, NOT Yandex Sans Text — the new app must add YandexSansText-Medium.ttf or alias to Yango
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/OfflineGlowBackground.swift, OfflineHeaderGlow.swift, OfflinePullGlow.swift, 'Glow Button/' — existing blurred-gradient glow implementations reusable for the pulse effect
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/AnimatedIconButton.swift — icon press/scale animation pattern
- /tmp/figma_tabbar/*.svg — downloaded glyph + pulse SVG sources (temp; re-export before implementation, MCP URLs expire in 7 days)

## OPEN QUESTIONS
- Tab-switch animation: does the pulse glow crossfade+slide (7→11px bottom offset) per Figma variants, or travel horizontally between tabs? Duration/spring?
- Should the underlay have a real progressive blur (VariableBlur) under the black scrim, or scrim only? Figma has backdrop-blur present but set to 0.
- Is Плюс the default/active tab at launch (it is active in the tabbar master), and what does the Plus tab open — a hub screen?
- Reproduce the 3-layer white inner-shadow emboss on glyphs natively, or bake into exported assets (recommended)?
- Press/highlight state for tab buttons (scale? opacity?) — not present in the component set.
- Font licensing: use real Yandex Sans Text Medium files, or alias to the already-bundled YangoText-Medium?
- Behavior on devices without home indicator and on wider screens: keep 24pt side padding + equal-spacing, or fixed 6.75 gaps?
- Does the tabbar hide/collapse on scroll or when a player/sheet is open (BottomBarV2 has offline offsets — any analogous states here)?