# Privacy Policy — RecoveryBar

**Last updated:** March 22, 2026

## What data we access

RecoveryBar accesses the following data from your WHOOP account via the official WHOOP API:

- **Recovery**: Recovery score, heart rate variability (HRV), resting heart rate, blood oxygen (SpO2), skin temperature
- **Strain**: Daily strain score, calories burned, average and max heart rate
- **Sleep**: Sleep duration, sleep stages (REM, deep, light), performance, efficiency, consistency, respiratory rate
- **Workouts**: Activity type, workout strain, duration, heart rate, heart rate zone durations
- **Profile**: First name, last name (for display purposes only)
- **Body measurements**: Height, weight, max heart rate

## How your data is used

- All data is fetched **directly from the WHOOP API to your Mac**. No health data passes through any third-party server.
- Data is displayed locally in your macOS menu bar and is **never stored on disk** — it exists only in memory while the app is running.
- A lightweight auth proxy facilitates OAuth token exchange. It does **not** access, store, or log any health data or user tokens. The proxy collects minimal, anonymized usage analytics (see below).

## Auth proxy analytics

The auth proxy collects the following anonymized data to monitor service health:

- **Hashed IP addresses** (SHA-256, irreversible) to count unique users
- **Aggregate counts** of sign-in and token refresh requests
- **Timestamps** of the last sign-in event

No personally identifiable information, tokens, health data, or WHOOP account details are collected or stored by the proxy.

## Data storage

- OAuth tokens (access token and refresh token) are stored in your **macOS Keychain** (release builds) or a local file (development builds), encrypted at rest by Apple.
- No health data is stored on disk. All health data exists only in application memory.
- No analytics, tracking, or telemetry is collected by the macOS app itself.
- No data is shared with third parties.

## Data deletion

- Signing out of the app deletes all stored tokens.
- You can revoke access at any time from your WHOOP account settings at whoop.com.
- Uninstalling the app removes all local data.

## Open source

This application is open source under the MIT license. You can inspect the full source code to verify these claims.

## Contact

For questions about this privacy policy, open an issue at: https://github.com/itsowaisiqbal/recoverybar/issues

---

*RecoveryBar is not affiliated with or endorsed by WHOOP Inc.*
