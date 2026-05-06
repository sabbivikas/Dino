# Bugbot — Dino (iOS / SwiftUI / Firebase)

Project-specific review instructions for [Bugbot](https://cursor.com/docs/bugbot). Apply especially when PRs touch authentication, sync, storage, extensions, or Firebase configuration.

## Manual setup (cannot be done from the repo)

Do these once per organization/repo:

1. Connect the GitHub or GitLab repository in the [Cursor dashboard](https://cursor.com/dashboard).
2. Enable Bugbot for this repo in the [Bugbot dashboard](https://cursor.com/dashboard/bugbot).
3. Optional: comment `cursor review` or `bugbot run` on a PR to trigger a review manually; use `cursor review verbose=true` if debugging.

## Security and privacy — flag as blocking when appropriate

### Secrets and configuration

- Reject hardcoded API keys, OAuth client secrets, Apple Team IDs, App Store Connect keys, or Firebase private keys in source (including plist fragments committed by mistake).
- Flag verbose `print`/`NSLog`/`os_log` that may emit tokens, UIDs, email, journal text, or refresh tokens.
- Ensure `GoogleService-Info.plist` changes are intentional; remind that bundle IDs and URL schemes must match production vs debug.

### Firebase / Firestore

- Client code must **not** assume server-side validation exists; remind that correctness depends on `firestore.rules`.
- Flag writes that use attacker-controlled paths or cross-user IDs without server rules guaranteeing isolation.
- Note when new collections/subcollections are added under `users/{userId}` without corresponding rules updates (see [firestore.rules](../firestore.rules)).

### Authentication

- Review Google Sign-In / Firebase Auth flows for token handling, session edge cases, and sign-out clearing local state (see `AuthManager`, `SharedDataManager`).
- Flag bypass of onboarding or auth gates via deep links or notification actions.

### iOS: storage and surfaces

- Sensitive data must not rely on shared `UserDefaults` without scoping; App Group (`SharedDataManager`) data is visible to app extensions — flag new highly sensitive fields stored there without justification.
- Review entitlements and App Groups when changing targets (`DinoLiveActivity`, widgets): minimize exposed data.
- Keychain vs UserDefaults: credentials and long-lived secrets belong in Keychain.

### URL schemes and deep links

- Review `ContentView.handleDeepLink` and `dino://` hosts: unexpected hosts should not change sensitive state; tab switching from URLs/notifications should be bounded (no arbitrary destinations from untrusted input).

### Extensions / Live Activities

- Widget/Live Activity providers must not leak other users’ data; confirm shared payloads are user-scoped or non-sensitive.

## Swift / quality patterns

- Prefer `@MainActor` / thread-safe updates for `@Published` models touched from callbacks.
- New network or file I/O should handle cancellation and errors without silent data loss.

---

## Cursor Security Review (Teams / Enterprise only)

These agents are **not** configured from this file; they run on Cursor Cloud Agents.

1. Open [Security Review Dashboard](https://cursor.com/dashboard/security-review).
2. Create a **Security Review** automation triggered on **pull requests** for this repo (auth, `FirestoreSyncService`, `SharedDataManager`, extensions).
3. Create a **Vulnerability Scanner** automation with a **cron** schedule for periodic full-repo scans.
4. Attach at least one **tool or MCP** per Cursor docs (e.g. Slack, issue tracker, or internal security tooling).
5. Optional: add Bugbot **MCP** from the [Bugbot dashboard](https://cursor.com/dashboard/bugbot) (Team/Enterprise).

Documentation: [Security Review](https://cursor.com/docs/security-review).

## Repo-local security testing

See [SECURITY_TESTING.md](../SECURITY_TESTING.md) for Firestore rules CI, Dependabot, and mobile/Firebase manual testing guidance.
