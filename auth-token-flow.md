# Flutter ↔ Laravel Token Authentication Flow

This document explains how the Flutter app now works with the updated Laravel
token system.

## Backend Contract (Laravel)

Auth endpoints used by Flutter:

- `POST /api/auth/validate-email`
- `POST /api/auth/login`
- `POST /api/auth/register`
- `POST /api/auth/forgot-password`
- `POST /api/auth/refresh`
- `POST /api/auth/logout` (requires Bearer token)
- `GET /api/auth/user` (requires Bearer token)

Laravel returns a **token pair** on login/register/refresh:

- `access_token` (short-lived)
- `refresh_token` (longer-lived, rotated on refresh)
- `device_uuid`
- `access_token_expires_at`
- `refresh_token_expires_at`
- `token_type` (`Bearer`)

## Flutter Implementation Summary

Updated file:

- `lib/data/services/auth_service.dart`

### 1) Session model in Flutter

In-memory session fields:

- `_accessToken`
- `_refreshToken`
- `_deviceUuid`
- `_currentUser`

Important behavior:

- Tokens are **not persisted** across app restarts.
- Closing/killing the app clears memory, so login is required again.
- `device_uuid` is persisted in `SharedPreferences` so the device identity
  remains stable.

### 2) Device metadata sent to Laravel

For `login` and `register`, Flutter now sends:

- `device_uuid`
- `platform`
- `device_name`
- `app_version`

This matches Laravel validation requirements introduced in API auth.

### 3) Login/Register response handling

On successful `login` or `register`, Flutter now reads:

- `access_token`
- `refresh_token`
- `device_uuid`
- `user`

Then it stores them in-memory and sets `Authorization: Bearer <access_token>`
for future calls.

Backward fallback remains:

- If backend still returns old `token`, Flutter accepts it as `access_token`
  fallback.

### 4) Automatic refresh flow

When a protected request returns `401`:

1. Flutter calls `POST /api/auth/refresh` with:
   - `refresh_token`
   - `device_uuid`
2. If refresh succeeds, Flutter replaces:
   - `_accessToken`
   - `_refreshToken` (rotation-aware)
   - `_deviceUuid` (if returned)
3. Flutter retries the original protected request once.
4. If refresh fails, request remains unauthorized; app should redirect user to
   login when appropriate.

### 5) Forced logout UX (cross-platform single session)

- Laravel web: heartbeat writes `toast-next` and redirects to login when session
  is invalidated.
- Flutter: app-level session watcher checks every 10s (and on app resume). If
  invalidated, it clears session, redirects to landing, and shows a toast
  message.

Reason codes returned by `POST /api/auth/refresh` on invalid session:

- `SESSION_REVOKED`
- `REFRESH_TOKEN_EXPIRED`
- `DEVICE_MISMATCH`
- `INVALID_REFRESH_TOKEN`

Flutter maps these reasons to user-facing logout messages.

## API Call Behavior by Method

### `validateEmail(email)`

- Public endpoint.
- No token needed.

### `login(email, authMethod, password|pin)`

- Public endpoint.
- Sends credentials + device payload.
- Stores returned token pair in-memory.

### `register(name, email, password, passwordConfirmation, companyCode)`

- Public endpoint.
- Sends registration data + device payload.
- Stores returned token pair in-memory.

### `forgotPassword(email)`

- Public endpoint.
- Uses Laravel broker-backed reset flow.

### `getUser()`

- Protected endpoint.
- Uses current access token.
- On `401`, performs refresh and retries once.
- Updates in-memory user profile when successful.

### `logout()`

- Protected endpoint.
- Calls backend logout (which revokes all device/session tokens in current
  Laravel setup).
- Clears local in-memory session regardless of network response.

## `utility_user_login_register` behavior for Flutter/API

Flutter/API auth updates the same login history table used by Laravel web:

- On successful API login/register/refresh token issuance:
  - creates or touches an active row with `session_id = api:<device_uuid>`
- On authenticated API requests:
  - middleware updates `last_connected_time` for that API session row
- On API logout:
  - active rows are ended with `session_end_type = LOGGED OUT`

This keeps web and mobile session history in one table while preserving a unique
session identity per mobile device.

## Sequence Diagram (Conceptual)

1. User logs in/registers.
2. Laravel returns token pair + user data.
3. Flutter stores access token + refresh token + device UUID in memory.
4. Flutter calls protected APIs using Bearer access token.
5. Access token expires → backend returns `401`.
6. Flutter refreshes token using refresh token + device UUID.
7. Laravel rotates refresh token and returns new token pair.
8. Flutter retries original API call successfully.

## Error Scenarios

### Invalid credentials on login

- Laravel returns `422` with message.
- Flutter displays message.

### Expired or revoked refresh token

- Refresh endpoint returns unauthorized/failed response.
- Flutter cannot recover session automatically.
- User must log in again.

### Network errors

- Standard Dio error handling returns a consistent fallback message.

## Security Notes

Current implementation mirrors prior app behavior (memory-only auth session).
For stronger production posture:

1. Store tokens in secure storage (`flutter_secure_storage`) instead of memory.
2. Add centralized auth state notifier to force redirect to login when refresh
   fails globally.
3. Consider proactive refresh using `access_token_expires_at` to refresh before
   expiry.

## QA Checklist

1. Login with password and with PIN.
2. Register new user and verify immediate authenticated state.
3. Call `getUser` after manually expiring access token server-side and verify
   auto refresh.
4. Logout and verify all protected calls fail until re-login.
5. Reopen app and verify login is required again (memory-only behavior).
