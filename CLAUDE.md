# whoop-menubar

A native macOS menu bar widget that displays WHOOP recovery, strain, and sleep data.

## Project Overview

- **Platform**: macOS (Apple Silicon + Intel)
- **Language**: Swift, SwiftUI
- **Min Deployment**: macOS 14.0 (Sonoma)
- **License**: MIT
- **Distribution**: Open source via GitHub, distributed as `.dmg`

Not affiliated with or endorsed by WHOOP Inc.

## Architecture

### Two-Component System

```
┌──────────────────────────────┐
│    macOS Menu Bar App         │
│    (Swift/SwiftUI)            │
│                               │
│  - Menu bar icon + popover    │
│  - Recovery score (color)     │
│  - Strain gauge               │
│  - Sleep performance          │
│  - Tokens stored in Keychain  │
│  - Polls WHOOP API ~15min     │
│  - Direct API calls for data  │
└──────────────┬───────────────┘
               │
               │ Auth only (token exchange + refresh)
               ▼
┌──────────────────────────────┐
│    Auth Proxy                 │
│    (Cloudflare Worker)        │
│                               │
│  - Holds client_secret        │
│  - POST /token — exchange     │
│  - POST /refresh — refresh    │
│  - CORS locked to app         │
│  - Nothing else               │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│    WHOOP API                  │
│    api.prod.whoop.com         │
│    /developer/v2/*            │
└──────────────────────────────┘
```

### Why Two Components?

WHOOP's OAuth requires a `client_secret` for token exchange (no PKCE support). The secret cannot be shipped in an open source binary. A lightweight auth proxy holds the secret server-side. All data fetching happens directly from the widget to the WHOOP API — the proxy only handles 2-3 auth requests per user.

## Authentication Flow

### First Launch (One-Time)

1. User clicks "Sign in with WHOOP" in the menu bar popover
2. App opens default browser to WHOOP OAuth URL:
   - `https://api.prod.whoop.com/oauth/oauth2/auth`
   - Params: `client_id`, `redirect_uri`, `scope`, `state`, `response_type=code`
3. User logs in with their normal WHOOP credentials and approves scopes
4. WHOOP redirects to `http://localhost:{PORT}/callback` with auth `code`
5. App's local HTTP server captures the code
6. App sends code to auth proxy → proxy exchanges for tokens using `client_secret`
7. Proxy returns `access_token` + `refresh_token` to the app
8. App stores both tokens in macOS Keychain
9. App fetches initial data and displays in menu bar

### Subsequent Launches

1. App reads tokens from Keychain
2. If `access_token` is expired, sends `refresh_token` to proxy → gets new pair
3. Fetches data directly from WHOOP API
4. Displays in menu bar

### Fallback: User-Provided Credentials

For users who prefer not to use the proxy (or if the proxy is down):
1. User creates their own app at `developer-dashboard.whoop.com`
2. Pastes `client_id` and `client_secret` into the widget's settings
3. Widget handles OAuth flow entirely locally (no proxy needed)
4. Everything else works the same

## OAuth Scopes

| Scope | Used For |
|-------|----------|
| `read:recovery` | Recovery score, HRV, resting HR, SpO2, skin temp |
| `read:cycles` | Daily strain, kilojoules, average/max HR |
| `read:sleep` | Sleep stages, duration, efficiency, respiratory rate |
| `read:profile` | User name (for display) |
| `offline` | Refresh token (required for persistent sessions) |

## WHOOP API Endpoints

Base URL: `https://api.prod.whoop.com/developer/v2/`

| Endpoint | Data |
|----------|------|
| `GET user/profile/basic` | User name, email |
| `GET cycle` | Daily cycles with strain scores |
| `GET activity/recovery` | Recovery scores, HRV, resting HR, SpO2 |
| `GET activity/sleep` | Sleep records with stage breakdowns |

All collection endpoints support `start`, `end`, `limit`, `nextToken` params.

### Rate Limits

- 100 requests/minute, 10,000/day (per app)
- Widget polls every 15 minutes = ~96 requests/day per user (well within limits)
- Check `score_state` before reading `score` fields (can be `PENDING_SCORE` or `UNSCORABLE`)

## Menu Bar UI

### Collapsed State (Menu Bar Icon)

Display recovery score as a colored number in the menu bar:
- Green (67-100%): good recovery
- Yellow (34-66%): moderate recovery
- Red (1-33%): poor recovery

### Expanded State (Popover)

```
┌─────────────────────────────┐
│  Recovery          72%  🟢  │
│  ├─ HRV            65ms    │
│  ├─ Resting HR     52bpm   │
│  ├─ SpO2           97%     │
│  └─ Skin Temp      33.2°C  │
│                             │
│  Strain            12.5    │
│  ├─ Calories       2,030   │
│  └─ Max HR         175bpm  │
│                             │
│  Sleep              7h 30m │
│  ├─ Performance    85%     │
│  ├─ Efficiency     87%     │
│  └─ Consistency    78%     │
│                             │
│  Last updated: 2 min ago    │
│  ─────────────────────────  │
│  ⚙ Settings    ↻ Refresh   │
└─────────────────────────────┘
```

## Project Structure

```
whoop-menubar/
├── CLAUDE.md
├── README.md
├── LICENSE
├── .gitignore
│
├── WhoopMenubar/                  # Xcode project
│   ├── App/
│   │   ├── WhoopMenubarApp.swift  # @main entry, MenuBarExtra
│   │   └── AppState.swift         # Global app state (ObservableObject)
│   │
│   ├── Auth/
│   │   ├── AuthManager.swift      # OAuth flow orchestration
│   │   ├── KeychainStore.swift    # Secure token storage
│   │   ├── LocalAuthServer.swift  # localhost HTTP server for OAuth callback
│   │   └── AuthProxyClient.swift  # Talks to Cloudflare Worker proxy
│   │
│   ├── API/
│   │   ├── WhoopAPIClient.swift   # HTTP client for WHOOP API
│   │   ├── Endpoints.swift        # Endpoint definitions
│   │   └── Models/
│   │       ├── Recovery.swift
│   │       ├── Cycle.swift
│   │       ├── Sleep.swift
│   │       └── Profile.swift
│   │
│   ├── Views/
│   │   ├── MenuBarView.swift      # Collapsed menu bar content
│   │   ├── PopoverView.swift      # Expanded popover
│   │   ├── RecoveryCard.swift     # Recovery section
│   │   ├── StrainCard.swift       # Strain section
│   │   ├── SleepCard.swift        # Sleep section
│   │   ├── SettingsView.swift     # Settings panel
│   │   └── SignInView.swift       # First-launch auth screen
│   │
│   ├── Services/
│   │   ├── DataSyncService.swift  # Periodic polling + data refresh
│   │   └── NotificationService.swift  # Optional alerts
│   │
│   └── Utilities/
│       ├── Constants.swift        # API URLs, intervals, color thresholds
│       └── Extensions.swift       # Date, Color, formatting helpers
│
├── AuthProxy/                     # Cloudflare Worker
│   ├── wrangler.toml              # Worker config
│   ├── src/
│   │   └── index.ts               # Token exchange + refresh endpoints
│   └── package.json
│
└── Tests/
    ├── AuthManagerTests.swift
    ├── WhoopAPIClientTests.swift
    ├── DataSyncServiceTests.swift
    └── ModelDecodingTests.swift
```

## Auth Proxy (Cloudflare Worker)

### Endpoints

**POST /token** — Exchange auth code for tokens
```
Request:  { "code": "...", "redirect_uri": "http://localhost:{PORT}/callback" }
Response: { "access_token": "...", "refresh_token": "...", "expires_in": 3600 }
```

**POST /refresh** — Refresh expired tokens
```
Request:  { "refresh_token": "..." }
Response: { "access_token": "...", "refresh_token": "...", "expires_in": 3600 }
```

### Security

- CORS restricted to expected origins
- No logging of tokens or secrets
- Rate limited per IP
- `client_id` and `client_secret` stored as Worker secrets (not in code)
- Proxy does NOT store any user tokens — stateless

### Hosting

- Cloudflare Workers free tier: 100,000 requests/day
- At 2-3 auth requests per user, supports ~30,000+ users on free tier
- Zero cold start, globally distributed

## Key Design Decisions

1. **Native Swift over Electron** — Lower memory footprint, proper macOS integration, Keychain access, no Chromium overhead. Menu bar apps should be lightweight.

2. **MenuBarExtra (SwiftUI)** — Available since macOS 13. Provides native menu bar presence with popover support. No AppKit workarounds needed.

3. **15-minute poll interval** — WHOOP data updates infrequently (recovery once/day, strain throughout day). 15 min balances freshness vs rate limits. User can manually refresh.

4. **Keychain for tokens** — macOS Keychain is the standard secure storage. Encrypted at rest, per-app access control, survives app updates.

5. **Immutable data models** — All API response models are `struct` with `let` properties. State updates create new instances, never mutate existing ones.

6. **Fallback to user credentials** — If the auth proxy is down or user prefers self-hosting, they can provide their own `client_id`/`client_secret`. The app works either way.

## WHOOP API Gotchas

- Refresh tokens are **single-use** — each refresh returns a new one. Must store the new token immediately.
- `score_state` can be `PENDING_SCORE` or `UNSCORABLE` — always check before reading `score` fields.
- Timestamps are **UTC ISO 8601** — timezone offset is a separate field.
- Sleep and workout IDs are **UUIDs** in v2 (not integers). Cycle IDs are integers.
- Pagination is **token-based** — use `nextToken`, no offset/skip support.
- No real-time streaming — polling only.

## Development Setup

1. Open `WhoopMenubar.xcodeproj` in Xcode
2. For proxy development: `cd AuthProxy && npx wrangler dev`
3. For local-only testing: use Settings → "Use own credentials" mode
4. Requires macOS 14.0+ SDK, Xcode 15+

## Rollout Plan

1. **Phase 1**: Build widget + auth proxy, test with own account (<10 users)
2. **Phase 2**: Submit for WHOOP app approval with screenshots
3. **Phase 3**: Ship open source repo with fallback (user-provided credentials)
4. **Phase 4**: Once approved, enable proxy flow for frictionless onboarding
