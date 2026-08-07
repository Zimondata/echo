# Secure native plan sync contract

Status: design gate only. No production auth was weakened and no secret was embedded in the iOS project.

## Why local preview is the current default

Echo production authenticates its owner through Telegram/browser state. The existing multi-user audit found that the Telegram authorization capability is not yet cryptographically bound to the browser session that initiated login. Reusing that contour for a native token would copy a known security flaw into iOS.

The app therefore uses `PlanSnapshot.preview()` and labels the source **Локальный preview**. It does not scrape cookies, bundle bot credentials, or call a broad trusted API.

## Required native auth flow

1. The app creates a random PKCE verifier/challenge and opens an `ASWebAuthenticationSession` to `https://echo.datapine.space/native/authorize`.
2. Echo binds the authorization request to the initiating browser session and PKCE challenge.
3. The user completes owner or future per-user authentication in the browser.
4. Echo returns a one-time, short-lived code through a registered universal link or custom callback URL.
5. The app exchanges `code + verifier` for:
   - short-lived access token;
   - rotating refresh token;
   - only `plan:read` scope.
6. Tokens live in iOS Keychain, never App Group storage or `UserDefaults`.
7. Refresh reuse revokes the device session. Echo exposes a device-session list and revoke action.

## Minimum read-only API

```http
GET /api/v1/plan?from=2026-08-07&to=2026-09-07
Authorization: Bearer <short-lived access token>
```

```json
{
  "generated_at": "2026-08-07T20:00:00+02:00",
  "timezone": "Europe/Madrid",
  "items": [
    {
      "id": "calendar_event:123",
      "title": "Deep work",
      "starts_at": "2026-08-08T10:00:00+02:00",
      "ends_at": "2026-08-08T12:00:00+02:00",
      "kind": "calendar_event"
    }
  ]
}
```

Contract rules:

- principal is the authenticated user, never a request-supplied `user_id`;
- query returns only that principal's CalendarEvents, TimeBlocks, and Tasks;
- soft-deleted/private non-plan records are excluded;
- bounded date range, pagination/size limit, rate limiting, token expiry, audit event, and revocation are mandatory;
- no health records, captures, transcripts, private Obsidian, agent runtime, or broad settings;
- API is read-only in the first slice;
- cross-user and stolen-code tests must pass before production enablement.

## App integration seam

`PlanSnapshot` already includes source provenance (`preview`, `local`, `echoServer`). A later `NativePlanRepository` can decode the endpoint into the existing core without changing PlanView, shield copy, or App Group snapshot format.
