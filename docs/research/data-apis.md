# MusicPlayer Data Layer Analysis + API Research for "Яндекс Плюс" prototype

## 1. Layer topology

Data flow: `DeezerService` (actor, raw HTTP) → `DeezerModels` (DTO) → `ContentCurationManager` (@MainActor orchestrator, DTO→UI-model mapping) → UI models (`Track`/`AlbumCardItem`/`NewReleaseData`) → views via `CachedAsyncImage`. Note: `Services/` dir contains the real network layer (DeezerService, ContentCurationManager, OpenAIService, AudioPlayerManager) — the task's `Data/` list is only part of the picture. `docs/CLAUDE.md` is STALE: says "no networking, all data static/mock" — predates Deezer integration.

## 2. External APIs called

### Deezer (anonymous, no auth at all)
- `MusicPlayer/Services/DeezerService.swift` — `actor`, singleton, `baseURL = "https://api.deezer.com"` (:28).
- Endpoints wrapped (:55–168): `/search/album`, `/search/artist`, `/search/track`, `/album/{id}`, `/artist/{id}`, `/artist/{id}/albums`, `/album/{id}/tracks` (limit=100), `/genre`, `/genre/{id}/artists`, `/playlist/{id}`, `/playlist/{id}/tracks`, `/chart/0/tracks`, `/chart/0/albums`.
- Client-side rate limiting (:33–35, :208–218): sliding 5s window, `maxRequestsPer5Seconds = 50` (matches Deezer's official 50 req/5s quota); sleeps 1s when window full; `minRequestInterval = 0.11` is declared but never used. 429 → `DeezerError.rateLimited` (:193–194).
- Headers: `Accept-Language: en` (:185). Decoder: `.convertFromSnakeCase` (:49). Timeout 15s (:45).
- Geo-bias gotcha documented in code: anonymous `/genre/{id}/artists` and charts are IP-localized (in Serbia → Serbian artists) — worked around via fixed international playlist IDs (`DeezerMusicScope.swift:36–43`).

### OpenAI (key-based, only non-free API)
- `MusicPlayer/Services/OpenAIService.swift` — `POST https://api.openai.com/v1/chat/completions`, model `gpt-4o-mini` (:6–7), `Bearer APIKeys.openAI` (:100), max_tokens 80, temperature 0.35, 10s timeout. Generates one-sentence music fact in `Locale.current` language for the player.
- `MusicPlayer/MusicPlayer/APIKeys.swift` — 5 lines: `enum APIKeys { static let openAI = "<literal secret string>" }`. Gitignored (`.gitignore` contains `MusicPlayer/APIKeys.swift`), so key never in git; file must exist locally to compile.

## 3. Mock vs live boundary

Pattern: every UI model carries BOTH a bundled-asset name (String) and an optional remote URL; views render URL when available, else asset. This is the single most reusable idea for the superapp.
- `Track` (`Features/TrackRow.swift:8–21`): `albumCover: String` + `albumCoverURL/artistImageURL/artistThumbnailURL/previewURL: URL?` + `deezerAlbumId: Int?`.
- `AlbumCardItem` (`Features/AlbumCarousel.swift:72–79`), `NewReleaseData` (`Features/NewReleaseCard.swift:342–365`, Codable, computed id from strings), `AlbumData` (`Data/AlbumDataManager.swift:4–15`), `ShareableEntity` (`Data/ShareableEntity.swift` — value struct + static factories `.album()/.playlist()` for share overlay), `GenreDefinition` (`Data/GenreCatalog.swift:3–11`) — all follow it.
- Pure-mock fallbacks: `AlbumDataManager.getAlbumData` (`Data/AlbumDataManager.swift:23–31`) returns hardcoded stub (`"album"`, `"userpic"`, year 2024, empty bio); `Screens/Album.swift:173` = `loadedAlbumData ?? AlbumDataManager…`, live path via `DeezerService.getAlbum`/`getAlbumTracks` at `Album.swift:117,139`.
- `TrackDataManager` (`Data/TrackDataManager.swift`) is a 13-line shim: `getSampleTracks()` just returns `ContentCurationManager.shared.curatedTracks` (kept for legacy call-site compatibility).
- Fully hardcoded curation/copy: `Data/GenreCatalog.swift` — 12 `GenreDefinition` entries + fallback (English card titles, genre names, 10 artist names each, bundled cover assets "1"–"12") for the Wizard onboarding; `Data/Copy.swift` — `ToastCopy.likeTitles` array of 16 strings + `randomLikeTitle()`; `Data/DeezerMusicScope.swift` — hardcoded Deezer genre-id allowlist `[85,152,464,129,169,153,116,132,106,113]` (:21–32), 3 international seed playlist IDs (:39–43), 8 Downloads-showcase playlist IDs (:46–55), paging constants (`playlistTrackPages=3`, `playlistTracksPageLimit=50`).
- Bundled assets in `Assets.xcassets`: `album`, `userpic`, `albums/`, `artists/`, `playlist covers/`, `wizard covers/` — placeholders shown until network hydrates.

## 4. Curation pipeline (ContentCurationManager.swift, 442 lines, @MainActor ObservableObject singleton)

- `@Published private(set)`: `curatedTracks [Track]`, `featuredAlbums [AlbumCardItem]`, `newReleases [NewReleaseData]`, `albumGroups [(title, albums)]`, `downloadedPlaylistShowcase`, `myVibeGeneratorTracks`, `isLoading`, `error`.
- Staged lazy loading, guarded by `hasLoadedX` bools:
  - `loadInitial()` (:54–64), called from `MusicApp.swift:76` in `.task`: `discoverArtists()` (:187–201) pages 3 seed playlists × 3 pages × 50 tracks → dedup artists by id → shuffle; `refillAlbumQueue(artistsToProcess:40)` (:212–234) — TaskGroup fan-out `getArtistAlbums` per artist, filter by `album.genreId ∈ allowedAlbumGenreIds`, dedup vs `seenAlbumIds`; `loadCuratedAlbumBatch(albumCount:10)` (:236–316) — TaskGroup `getAlbumTracks` per album to pick a random preview-bearing track; builds `AlbumCardItem` + `Track`.
  - `loadRemainingInBackground()` (:174–182), `MusicApp.swift:79`: 25 iterations of refill(15)+batch(10).
  - `loadNewReleasesIfNeeded()` (:99–142), on Trends screen appear: 12 random featured ids → parallel `getAlbum` → keep only albums whose artist has photo → sort by releaseDate desc → 6 cards; first card gets `videoName: "pj-harvey.mov"`.
  - `loadMyVibeGeneratorTracksIfNeeded()` (:68–96): once per session, dedup via stored Task; falls back to paging playlists with per-album genre check + `albumPassCache` (:411–441).
- `albumGroups` frozen after first non-empty build (`forYouCarouselGroupsFrozenForSession`, :310–315) so background loads don't jiggle carousels; 3 fixed carousel titles "Top charts"/"Trending now"/"More music" (:319–337).
- Image URL upsize trick `xlURL()` (:347–355): regex-replace `/\d+x\d+-` → `/1000x1000-` in Deezer CDN URLs.

## 5. Caching strategy

Four independent layers:
1. HTTP: `URLSession` `URLCache` in DeezerService (20 MB mem / 100 MB disk, diskPath `"deezer_cache"`, policy `.returnCacheDataElseLoad`; chart/playlist paths forced `.reloadIgnoringLocalCacheData` at :187–189). Separate `ImageLoader.session` URLCache 50 MB / 200 MB (`Features/CachedAsyncImage.swift:53–60`).
2. Decoded images: `ImageLoader.cache = NSCache<NSURL, UIImage>` countLimit 200, totalCostLimit 100 MB, cost = raw data byte count (:45–48, :67). Plus two `NSCache<NSURL, UIColor>` for player-gradient dominant colors (:50–51), computed via CIAreaAverage on top/bottom image halves, top darkened 30% (:73–88, :104–126).
3. Curation disk cache: `Data/CurationCache.swift` — versioned (`version = 4`) JSON of `CachedData{tracks, albums, releases}` to `Caches/deezer_curation.json`, atomic write, auto-`clear()` on version mismatch or decode failure. **DEAD CODE: zero call sites in the codebase (grep-verified)** — designed for warm-launch but never wired; ready-made for the new app.
4. AI facts: `Data/MusicFactManager.swift` — two-tier: in-memory `[String:String]` + UserDefaults blob key `"music_fact_cache"`; cache key `"\(title)_\(artist)"` (:52–54). `triggerPlay` fires OpenAI only on miss with `currentTask` cancellation on rapid swipes (:14–40); `showCachedFact` is read-only, never hits network (:43–48).

## 6. Image loading pipeline

`CachedAsyncImage` (`Features/CachedAsyncImage.swift:4–40`): SwiftUI View taking `url: URL?` + `assetName: String` + contentMode; `.task(id: url)` async loads; `resolvedImage` priority = NSCache hit → async-loaded → `UIImage(named: assetName)`; placeholder = white 8% rectangle. `ImageLoader.load` (:62–69): cache check → `session.data` → `UIImage(data:)` → cache insert. `ImageLoader.preload(_:)` (:90–99): fire-and-forget `Task.detached(priority: .utility)` per URL. No downsampling/decode-for-display — full-res UIImages held in cache (acceptable at prototype scale; 1000×1000 covers).

## 7. ATS / transport

`Info.plist:5–9` — `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true` (blanket). All APIs used are HTTPS, so this is belt-and-suspenders; keep the same for the new app to avoid any friction with poster CDNs. CORS is irrelevant for native `URLSession` (browser-only mechanism) — only matters if a web build ever appears.

## 8. API research for the superapp

### (a) Movies with Russian titles/posters
| API | Auth | Free limits | Notes |
|---|---|---|---|
| **kinopoisk.dev → now poiskkino.dev** | key via Telegram bot `@poiskkinodev_bot`, header `X-API-KEY` | 200 req/day free tier | `https://api.kinopoisk.dev/v1.4/movie/{id}`, `/v1.4/movie/search?query=`; best native RU data (KP ratings, RU posters/titles); 200/day is tight — pair with the CurationCache pattern (fetch once, serve from disk) |
| **kinopoiskapiunofficial.tech** | free registration on site → `X-API-KEY` | ~500 req/day cited by clients; official limit 20 req/sec, 429 above | `/api/v2.2/films/{id}`, `/api/v2.1/films/search-by-keyword`, `/api/v2.2/films/collections?type=TOP_POPULAR_ALL` — ready-made chart endpoint mirrors Deezer's `/chart/0/*` role; RU posters via their CDN |
| **TMDB** | free API key/v4 bearer, instant approval for personal use | ~40 req/sec soft IP limit (hard 40/10s limit removed 2019) | `language=ru-RU` returns translated title+overview+localized poster in one param; image CDN `image.tmdb.org`. CAVEAT: api.themoviedb.org / image.tmdb.org are blocked in Russia by Roskomnadzor — fine from Serbia, dead on a RU demo network without VPN. RU-specific coverage weaker than Kinopoisk-derived APIs |

Recommendation: kinopoiskapiunofficial.tech (free, higher quota than poiskkino.dev, has collections endpoint) with TMDB as fallback if demo location allows.

### (b) Books with Russian covers
| API | Auth | Free limits | Notes |
|---|---|---|---|
| **Google Books** | keyless works but unreliable (shared global quota → 429); free key = ~1000 req/day courtesy quota | 1 req/sec/user | `GET https://www.googleapis.com/books/v1/volumes?q=…&langRestrict=ru`; `imageLinks.thumbnail` (zoom-param URL trick for bigger sizes); large/extraLarge covers require per-volume fetch by id; best practical RU-cover source |
| **Open Library** | none; polite `User-Agent` w/ email → 3 req/sec (1 req/sec anonymous) | covers by `cover_i`/OLID unlimited; ISBN-based cover lookups 100 req/5 min/IP | `https://openlibrary.org/search.json?q=…&lang=ru` returns `cover_i` → `https://covers.openlibrary.org/b/id/{cover_i}-L.jpg`; RU-edition coverage sparse/dated — weaker fit for Букмейт look |

Recommendation: Google Books with a free key as primary; Open Library as zero-config fallback. For a Букмейт-like feel, a hardcoded seed list of RU bestseller titles/volume-ids (analog of `downloadsShowcasePlaylistIds`) beats live search.

### (c) Music
| API | Auth | Free limits | Notes |
|---|---|---|---|
| **Deezer** (incumbent) | none | 50 req/5s (already enforced by DeezerService throttle) | Proven in this codebase; 30s preview MP3s; 1000×1000 covers via URL rewrite; reuse DeezerService verbatim |
| **iTunes Search** | none | ~20 calls/min/IP, 429/403 above (Apple: "approximately, subject to change") | `https://itunes.apple.com/search?term=…&country=RU&entity=song/album/movie/ebook&limit=N`; `artworkUrl100` upscalable by URL substitution (100x100→600x600); could theoretically cover music+movies+books in one API, but 20/min is far too tight for carousel hydration, and RU storefront catalog is thin post-2022 |

Recommendation: keep Deezer; port `DeezerService`/`DeezerModels`/`DeezerMusicScope`/`ContentCurationManager` nearly as-is for the Музыка tab.

Sources: [poiskkino.dev](https://poiskkino.dev/), [kinopoiskdev docs](https://kinopoiskdev.readme.io/), [kinopoiskapiunofficial.tech](https://kinopoiskapiunofficial.tech/), [its changelog](https://kinopoiskapiunofficial.tech/changes), [TMDB rate limiting talk](https://www.themoviedb.org/talk/5d34aec717792c0011bc9bd9), [TMDB getting started](https://developer.themoviedb.org/docs/getting-started), [TMDB language param talk](https://www.themoviedb.org/talk/58d41c209251411fd5018786), [Apple iTunes Search API docs](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html), [Google Books using the API](https://developers.google.com/books/docs/v1/using), [Google Books quota thread](https://discuss.google.dev/t/requesting-higher-quota-for-google-books-api-bookquest-app/286093), [Open Library APIs](https://openlibrary.org/developers/api), [Open Library Covers API](https://openlibrary.org/dev/docs/api/covers), [Open Library Search API](https://openlibrary.org/dev/docs/api/search), [coverstore rate-limit post](https://blog.openlibrary.org/2011/04/27/coverstore-improvements/).

## 9. Architecture implications for the new app

- Generalize `DeezerService` into per-domain actors (`KinopoiskService`, `BooksService`, `MusicService`) sharing one template: actor + singleton + URLCache + sliding-window throttle + generic `fetch<T: Decodable>` + snake_case decoder + typed error enum with `.rateLimited`.
- Keep the dual-source model pattern (assetName + URL?) — it is what makes the prototype demoable offline/before hydration.
- Wire up the (currently dead) `CurationCache` versioned-disk-cache pattern from day one — critical for poiskkino.dev's 200 req/day and Google Books' 1000/day budgets: hydrate once, replay from disk.
- `DeezerMusicScope`-style config enums per domain (hardcoded seed IDs/collections) are the cheapest way to get an editorially-curated "Yandex" feel without search-quality risk.
- `APIKeys` enum + gitignore for Kinopoisk/TMDB/Google keys; `NSAllowsArbitraryLoads=true` in Info.plist as before; CORS is a non-issue on iOS.
- `MusicFactManager` (two-tier cache + task cancellation + OpenAI) is a ready template for an Алиса feature.

## REUSABLE
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Services/DeezerService.swift — actor service template: singleton, URLCache (20/100MB) + .returnCacheDataElseLoad, sliding-window throttle (50 req/5s), generic fetch<T: Decodable> with snake_case decoder, typed DeezerError incl. .rateLimited; clone per API (Kinopoisk/Books)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Data/DeezerModels.swift — DTO pattern: plain Decodable structs + generic DeezerSearchResponse<T>{data,total,next} wrapper; replicate per API
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Data/DeezerMusicScope.swift — static config enum of hardcoded curation IDs (genre allowlist, seed playlist ids, paging constants); template for per-domain editorial curation (movie collections, book seed lists)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Services/ContentCurationManager.swift — @MainActor ObservableObject singleton orchestrator: staged lazy loading (loadInitial/loadRemainingInBackground/loadXIfNeeded guards), TaskGroup fan-out, DTO→UI mapping, seenIds dedup, frozen-carousel-groups trick, xlURL() Deezer CDN 1000x1000 regex upsize
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift — drop-in image pipeline: CachedAsyncImage(url:assetName:) view + ImageLoader (NSCache 200 items/100MB, URLCache 50/200MB, preload(), CIAreaAverage dominant-color pair for gradient backgrounds); reuse verbatim
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Data/CurationCache.swift — versioned JSON disk cache to Caches/ (auto-invalidate on version bump/decode failure); currently DEAD CODE (zero call sites) but exactly what the new app needs for 200-1000 req/day API budgets
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Data/MusicFactManager.swift — two-tier cache (memory dict + UserDefaults) keyed by title_artist, fire-API-only-on-miss, Task cancellation on rapid navigation; template for Алиса/AI-fact features
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Services/OpenAIService.swift — minimal chat-completions client (gpt-4o-mini, locale-aware prompt, 10s timeout)
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/APIKeys.swift + .gitignore entry — gitignored enum for secrets; extend with kinopoisk/tmdb/googleBooks keys
- Dual-source UI model pattern (bundled assetName String + optional URL? fields): Track at Features/TrackRow.swift:8-21, AlbumCardItem at Features/AlbumCarousel.swift:72-79, NewReleaseData at Features/NewReleaseCard.swift:342-365, ShareableEntity at Data/ShareableEntity.swift — enables offline-demoable mock fallback before network hydration
- /Users/dimazhuravlev/Repos/MusicPlayer/Info.plist — NSAllowsArbitraryLoads=true ATS blanket; copy for new app
- /Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Data/Copy.swift + Data/GenreCatalog.swift — hardcoded copy/curation-catalog pattern for toast strings and onboarding wizard content

## OPEN QUESTIONS
- Where will the prototype be demoed (Serbia vs Russia network)? TMDB api/image CDN is blocked in Russia — this decides TMDB vs kinopoiskapiunofficial.tech/poiskkino.dev as the movie source.
- Is poiskkino.dev's 200 req/day free tier acceptable (requires Telegram-bot key + aggressive disk caching), or prefer kinopoiskapiunofficial.tech (~500/day, needs site registration) / keyed TMDB (effectively unlimited)?
- Should Алиса content be live-generated via the existing OpenAI key/pattern (MusicFactManager+OpenAIService) or fully mocked strings?
- Should movie/book showcases be hardcoded seed-ID lists (Deezer downloadsShowcasePlaylistIds pattern — deterministic, demo-safe) or dynamic charts/search (varied but riskier on stage)?
- Keep Deezer for the Музыка tab as-is, or unify all three domains behind fewer APIs (e.g. iTunes Search covers music+movies+ebooks but at 20 req/min and thin RU catalog)?
- Should the new app finally wire the CurationCache warm-launch disk cache (dead code in MusicPlayer) — recommended given daily API quotas — and is stale-until-refresh content acceptable for the demo?