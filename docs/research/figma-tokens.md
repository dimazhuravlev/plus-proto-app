# Figma design-token layer — file 0HzFEKtm9oYdkksrDg7U14, section "For Claude — Яндекс Плюс" (2004:10700)

Variable defs were NOT empty — all 5 nodes returned bound variables. Raw values below marked (raw) come from get_design_context on tabbar 2004:9169, action bar 2001:111005, header 2004:10773 + metadata/screenshots, because the variable layer covers only colors/typography/one blur effect. There are NO spacing/radius variables in the file — all spacing/radii are hardcoded raw values. Dark theme only, no light mode present.

## 1. COLORS (variable name → hex, RGBA of white unless noted)

| Token (Figma variable) | Value | Usage observed |
|---|---|---|
| `Fill/One` | `#FFFFFF` | primary text, active tab label, home indicator |
| `Fill/Six` | `#FFFFFF66` (white 40%) | inactive tab labels |
| `Fill/Subtitle` | `#FFFFFF80` (white 50%) | mini-player subtitle (artist name) |
| `Fill/Nine` | `#FFFFFF14` (white 8%) | 0.66px borders on glass pills / album thumb |
| `Fill/Ten` | `#FFFFFF0F` (white 6%) | mini-player progress fill |
| `Buttons/Primary` | `#FFFFFF1A` (white 10%) | glass button fill (like/dismiss circles) |
| `Buttons/Secondary` | `#FFFFFF14` (white 8%) | secondary button fill (Rate chips) |
| `Plus/Solid One` | `#D88DFC` | Плюс brand accent (active tab tint/pulse) |
| `System/iOS Navbar darkBlur` | `#141414B2` (#141414 70%) | navbar/status-bar overlay fill, pairs with blur 70 |
| `Symbol Stroke` | `""` (empty/unresolved) | tab icon border — actual raw values below |

Raw colors not in variables:
- Tab icon "symbol" tile fill: `rgba(255,255,255,0.10)`; border inactive `rgba(255,255,255,0.04)` @ 0.66px; border active `rgba(255,255,255,0.06)` @ 0.733px
- Action-bar pill fill: `rgba(255,255,255,0.10)` + `backdrop-blur 35` + border `Fill/Nine` @ 0.66px  (the "glass" recipe)
- Search placeholder text: `rgba(255,255,255,0.30)`
- Screen base: black; ambient color comes from blurred cover images ("ambilight bg" nodes) — screen 2 shows warm dark red-brown glow
- Tabbar underlay: vertical eased gradient `rgba(0,0,0,0.9) → rgba(0,0,0,0)` over 210px, anchored bottom (16 stops, ease-out-ish: 0.9@0%, 0.867@11.2%, 0.828@20.5%, 0.783@28.1%, 0.732@34.4%, 0.678@39.6%, 0.619@44.1%, 0.556@48.1%, 0.491@51.9%, 0.424@55.9%, 0.354@60.4%, 0.284@65.6%, 0.212@71.9%, 0.141@79.5%, 0.07@88.8%, 0@100%)
- Header title fill: horizontal gradient text `#FFFFFF → rgba(255,255,255,0.6)` (bg-clip-text, to-white on left)

## 2. TYPOGRAPHY

Variables: `Font Family` = "Yango Text"; `Font Weight/Medium` = Medium(500); `Font Weight/Semibold` = Bold(700 — note the quirk: Semibold token resolves to Bold); `Font/Font Size/{11,13,24,28}`; `Font/Line Height/{14,16}`.

Text styles (variable-defined):
| Style | Spec |
|---|---|
| `Text S・13/Medium` | Yango Text Medium, 13/16, w500, ls 0 — mini-player title/subtitle, action-bar text |
| `Title S・24/Semibold` | Yango Text, 24/28, w700, ls 0 — card/section titles ("Моя Волна", movie/book titles) |

Raw text styles (no variable):
| Use | Spec |
|---|---|
| Screen header H1 | **YS Display Bold, 32/36, tracking −0.2**, gradient white→60% white fill (header 2004:10774) |
| Search placeholder | **YS Display Bold, 20/26**, `rgba(255,255,255,0.3)` ("Хочу послушать…") |
| Tabbar label | **Yandex Sans Text Medium, 11/14** (tabbar uses "Yandex Sans Text", mini-player uses "Yango Text" — two names, visually the same YS family; pick one bundled font or SF Pro fallback) |
| Book-card body text | serif-looking running text in "continue reading" card (node 2004:10718) — not inspected, minor |

Fonts appearing in file: **YS Display (Bold)**, **Yango Text (Medium)**, **Yandex Sans Text (Medium)**.

## 3. RADII (all raw, no variables)

| Token suggestion | Value | Where |
|---|---|---|
| radius.iconTile | 14 | 40×40 tab icon "symbol" tile |
| radius.pill | 32 | 60pt-high action-bar/search/mini-player pills |
| radius.circle | 1000 (∞) | 48×48 album art in mini-player, 40×40 card buttons |
| radius.movieThumb | 8 (outer) / 4 (inner img) | 88×54 movie-player chip in action bar |
| radius.bookThumb | 4 | 44×60 book-player chip |
| radius.coverSmall | 3 | 29×40 mini poster in header collage |
| radius.homeIndicator | 100 | 134×5 iOS home indicator |

## 4. SPACING / SIZING (all raw)

| Token suggestion | Value | Where |
|---|---|---|
| screen.width | 402 (screens) / 375 (tabbar master) | iPhone 16 Pro frame |
| margin.screen | 24 | header, tabs row, action bar horizontal padding |
| tabbar.height | 100 (62 tab item + home-indicator area 34, pt 4) |
| tabbar.item | 60×62, gap 2 icon→label, 5 tabs justify-between |
| tabbar.iconTile | 40×40; service icon leaf ~28.75 (32×32 master symbols, 2004:9170) |
| actionBar.height | 60; gap 8 between pills; pill padding 18h/8v; search icon 24 |
| miniPlayer | collapsed w 60; expanded pl 6 / pr 18 / py 8; album 48; internal gap 12; action icons 24, gap 18; progress overlay w 130 |
| navbar | overlay h 72 (+status bar 54; navbar frame 160 total incl. fade) |
| button.circle | 40×40, pair gap 6 (buttons frame = 86) |
| blur.glass | backdrop-blur 35 (pills) |
| blur.navbar | `BG Blur/System/iOS Specific` = BACKGROUND_BLUR radius **70** (the only effect variable) |
| card.movieCover | 193.88×279.05 (poster ~1:1.44) |
| card.albumCover | 186.17×186.17 |
| card.videoFrame | 289.54×179.55 (~16:10), edge-bleeds left (x −7.27) |
| card.rateBlock | 402×158 (4 chips: Нет/Ну такое/Супер/Шедевр) |
| homeIndicator | 134×5, container h 34, pb 8 |

## 5. Component inventory relevant to tokens
- `tabbar` 2004:9169 (master, 375×100): 5 tabs — Плюс, Музыка, Кинопоиск, Книги, Алиса; active state = white label + brighter border + colored "pulse" glow SVG behind tile (rotate-180, h 43 w 50, bottom-anchored)
- `service icon` set 2004:9170: 10 symbols (5 tabs × active/inactive), 32×32
- `action bar` 2001:111005: 4 states — `search` (284 search pill + 60 mini-player stub), `music player` (search icon pill + expanded mini-player), `book player` (search pill + 44×60 book chip, rotate 4°), `movie player` (search pill + 88×54 movie chip, rotate 4°)
- `search` variants 2001:110986: 3 placeholder rotations (Хочу послушать/почитать/посмотреть)
- screens: 2004:10701 (long scroll 402×2188, mixed movie/book/music/vibe cards), 2004:10785 (402×1138 "Полчаса в такси" scenario)

## 6. Swift-ready mapping note
Alpha-on-white scheme maps cleanly to `Color.white.opacity(x)`: One=1.0, Subtitle=0.5, Six=0.4, Primary=0.1, Nine=0.08, Secondary=0.08, Ten=0.06. Accent `plusAccent` = #D88DFC. `navbarBlurFill` = Color(hex 0x141414).opacity(0.7) + `.ultraThinMaterial`-style blur radius 70. Glass recipe = fill white 10% + stroke white 8% 0.66pt + blur 35.

Asset URLs from get_design_context (tab icon SVGs, pulse glow, search/love/pause icons) expire in ~7 days — re-export via download_assets when implementing.

## REUSABLE
- Figma node IDs for later extraction: section 2004:10700, screens 2004:10701 / 2004:10785, tabbar master 2004:9169, service-icon set 2004:9170 (10 variants 32x32), action bar 2001:111005 (4 states), search variants 2001:110986, header 2004:10773
- Glass recipe reusable as a single SwiftUI ViewModifier: white 10% fill + white 8% 0.66pt stroke + backdrop blur 35 + radius 32 (pills) or 14 (icon tiles)
- All neutral colors are white-with-opacity — one Color extension (Color.white.opacity(token)) covers the whole palette; only #D88DFC and #141414B2 are literal hexes
- Suggested target file for the sibling project: PlusApp/DesignSystem/Tokens.swift (Colors + Radii + Spacing + Typography enums), mirroring MusicPlayer conventions

## OPEN QUESTIONS
- Fonts: YS Display / Yango Text / Yandex Sans Text are Yandex-proprietary — bundle real YS fonts or approximate with SF Pro (Display Bold ~ YS Display Bold)? Affects the whole typography layer
- Active-tab 'pulse' glow: static SVG in Figma — should it animate (breathing/pulse) in the prototype, and does its color follow the active service (pink for Plus) per tab?
- Ambilight backgrounds: implement as blurred cover-image (live, per-content) or baked static gradients?
- Action bar has 4 states (search/music/book/movie) — what triggers transitions between them, and is the search-pill placeholder rotation animated?
- Header H1 uses gradient-filled text with inline media collage (rotated mini-covers between words) — how faithfully must this be reproduced?