# Privacy Policy — WHOOP Menubar

**Last updated:** March 22, 2026

## What data we access

WHOOP Menubar accesses the following data from your WHOOP account via the official WHOOP API:

- Recovery scores (HRV, resting heart rate, SpO2, skin temperature)
- Strain scores (daily strain, calories, heart rate)
- Sleep data (duration, performance, efficiency, consistency)
- Profile information (name, for display purposes only)

## How your data is used

- All data is fetched **directly from the WHOOP API to your Mac**. No data passes through any third-party server.
- Data is displayed locally in your macOS menu bar and is **never stored on disk** — it exists only in memory while the app is running.
- The only server-side component is a stateless auth proxy that facilitates OAuth token exchange. It **does not store, log, or retain** any user tokens or data.

## Data storage

- OAuth tokens (access token and refresh token) are stored in your **macOS Keychain**, which is encrypted at rest by Apple.
- No analytics, tracking, or telemetry is collected.
- No data is shared with third parties.

## Data deletion

- Signing out of the app deletes all tokens from your Keychain.
- You can revoke access at any time from your WHOOP account settings.
- Uninstalling the app removes all local data.

## Open source

This application is open source under the MIT license. You can inspect the full source code to verify these claims.

## Contact

For questions about this privacy policy, open an issue at: https://github.com/itsowaisiqbal/whoop-menubar/issues
