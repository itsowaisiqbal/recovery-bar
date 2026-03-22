# RecoveryBar

A native macOS menu bar app that displays your WHOOP recovery, strain, and sleep data at a glance.

Built by [@itsowaisiqbal](https://github.com/itsowaisiqbal). Not affiliated with or endorsed by WHOOP Inc.

## Features

- Recovery, strain, and sleep scores with radial progress rings
- Sub-metrics (HRV, resting HR, SpO2, skin temp, calories, efficiency, etc.)
- Today's activities (sleep, naps, workouts)
- Body measurements (height, weight, max HR)
- Liquid Glass UI on macOS 26+
- "DATA BY WHOOP" attribution per brand guidelines
- Secure OAuth via auth proxy (client_secret never touches the app)
- Tokens stored in macOS Keychain (encrypted at rest)
- Polls every 15 minutes (well within WHOOP rate limits)

## Setup

### 1. WHOOP Developer App

1. Go to [developer-dashboard.whoop.com](https://developer-dashboard.whoop.com)
2. Create a Team, then create an App
3. Set **Redirect URI**: `http://localhost:8919/callback`
4. Select all data scopes
5. Note your **Client ID** and **Client Secret**

### 2. Configure Client ID

```bash
cp Secrets.xcconfig.template Secrets.xcconfig
```

Edit `Secrets.xcconfig` and add your Client ID from the WHOOP Developer Dashboard:

```
WHOOP_CLIENT_ID = your-client-id-here
```

### 3. Build & Run

Open `WhoopMenubar.xcodeproj` in Xcode 15+ and build. Requires macOS 14.0+.

### 4. Auth Proxy (for contributors)

The auth proxy holds the `client_secret` server-side. To deploy your own:

```bash
cd AuthProxy
npm install
npx wrangler secret put WHOOP_CLIENT_ID
npx wrangler secret put WHOOP_CLIENT_SECRET
npx wrangler secret put STATS_SECRET
npx wrangler deploy
```

Update `Constants.swift` with your deployed worker URL.

## Architecture

```
macOS App (Swift/SwiftUI)
  ├── Menu bar icon (leaf)
  ├── Sign in with WHOOP (OAuth)
  ├── Fetches data directly from WHOOP API
  └── Tokens in macOS Keychain

Auth Proxy (Cloudflare Worker)
  ├── POST /token — exchange auth code
  ├── POST /refresh — refresh tokens
  └── Holds client_secret (never in app)
```

## Privacy

See [PRIVACY.md](PRIVACY.md). No health data is stored on disk or sent to third parties.

## Legal

WHOOP wordmark is property of WHOOP Inc., used per their Developer Brand Guidelines for required attribution.

## License

MIT — see [LICENSE](LICENSE)
