# Security Audit & Remediation Plan

**Date:** 2026-07-20
**Scope:** Full codebase — Supabase migrations, Dart services, client-side auth, local storage

---

## Executive Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 2 |
| HIGH | 4 |
| MEDIUM-HIGH | 3 |
| MEDIUM | 4 |
| LOW | 3 |

The two most urgent issues are **hardcoded admin credentials in SQL migrations** and **predictable temporary passwords**. The most systemic issue is the **lack of server-side role enforcement** — all authorization is client-side, meaning any authenticated user can call privileged Supabase endpoints directly.

---

## CRITICAL Findings

### C1. Hardcoded Admin Credentials in Migrations

**Severity:** CRITICAL
**Files:**
- `supabase/migrations/002_auth_email_password.sql:112`
- `supabase/migrations/006_fix_auth_schema_compatibility.sql:143`

**Description:**
The admin account is seeded with `admin@hotel.local` / `admin123` in plaintext SQL. These migrations are in the git repository, meaning anyone with repo read access knows the admin password. The password `admin123` is trivially guessable.

**Impact:** Full admin compromise. An attacker can log in as admin and manage all staff, rooms, and data.

**Remediation:**
1. Create migration `026_remove_hardcoded_admin.sql` that deletes the seeded admin user from `auth.users` and `staff`.
2. Add a comment-only migration that documents admin should be created via Supabase Dashboard or a one-time setup script with a strong password.
3. Force password change on first login (already partially implemented via the change password flow — ensure it's enforced).
4. Remove the hardcoded credentials from `plan.md` documentation (lines 27, 325, 331).

---

### C2. Predictable Temporary Passwords

**Severity:** CRITICAL
**Files:**
- `lib/services/auth_service.dart:97`
- `lib/services/auth_service.dart:177`

**Description:**
Temporary passwords are generated as:
```dart
'Temp${DateTime.now().millisecondsSinceEpoch % 10000}!'
'Reset${DateTime.now().millisecondsSinceEpoch % 10000}!'
```
This produces only 10,000 possible values (e.g., `Temp4521!`). The prefix is guessable, and the numeric part is a timestamp modulo — an attacker who knows the approximate creation time can brute-force the password in under a second.

**Impact:** An attacker who can enumerate staff (see C3) and knows approximate account creation time can log in as any staff member.

**Remediation:**
1. Replace with cryptographically secure random generation:
```dart
import 'dart:math';

String _generateSecurePassword({int length = 16}) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
  final rng = Random.secure();
  return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
}
```
2. Use this for both `createStaffAuth` and `resetStaffPassword`.
3. Ensure the generated password is displayed to the admin (it already is) and that the staff member changes it on first login.

---

## HIGH Findings

### H1. Unauthenticated Staff Data Exposure (Email Enumeration)

**Severity:** HIGH
**Files:**
- `supabase/migrations/003_staff_login_select.sql:4-8`
- `supabase/migrations/004_get_user_email_rpc.sql:12-14`

**Description:**
The `anon` (unauthenticated) role has `SELECT` access on the `staff` table filtered only by `is_active = true`. This means any HTTP request to the Supabase REST API without authentication can enumerate all active staff names, account names, login emails, roles, and user IDs.

**Impact:** Information disclosure. An attacker learns all staff identities, roles, and internal user IDs before even attempting authentication.

**Remediation (Option A — Scoped RPC):**
1. Create a new migration that drops the `anon` SELECT policy and grant.
2. Create an RPC function `get_staff_for_login()` that returns only `id` and `account_name` (no email, no user_id, no role):
```sql
CREATE OR REPLACE FUNCTION get_staff_for_login()
RETURNS TABLE(id UUID, account_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY SELECT s.id, s.account_name FROM staff s WHERE s.is_active = true ORDER BY s.account_name;
END;
$$;
```
3. Grant `EXECUTE` on this function to `anon`.
4. Update `auth_service.dart:fetchStaffForLogin()` to call this RPC instead of querying the `staff` table directly.

**Remediation (Option B — Keep dropdown, restrict columns):**
If the dropdown approach is preferred, restrict what `anon` can see:
```sql
CREATE OR REPLACE VIEW staff_login_view AS
SELECT id, account_name FROM staff WHERE is_active = true;
GRANT SELECT ON staff_login_view TO anon;
```

---

### H2. SECURITY DEFINER Functions Without Role Checks

**Severity:** HIGH
**Files:**
- `supabase/migrations/002_auth_email_password.sql:5-72` (`create_staff_auth`)
- `supabase/migrations/002_auth_email_password.sql:75-91` (`reset_staff_password`)
- `supabase/migrations/013_add_delete_staff_auth_rpc.sql:7-19` (`delete_staff_auth`)
- `supabase/migrations/019_auto_confirm_user.sql:6-19` (`auto_confirm_user`)
- `supabase/migrations/018_robust_create_staff_auth.sql:6-99` (latest `create_staff_auth`)

**Description:**
All four `SECURITY DEFINER` functions execute with the function owner's privileges (typically `postgres`) but have **no internal role verification**. Any authenticated user — including a cleaner — can call these functions via the Supabase RPC endpoint:
```
POST /rest/v1/rpc/create_staff_auth
POST /rest/v1/rpc/reset_staff_password
POST /rest/v1/rpc/delete_staff_auth
POST /rest/v1/rpc/auto_confirm_user
```

**Impact:** Privilege escalation. A cleaner can:
- Create new admin accounts
- Reset any user's password (including the admin)
- Delete any user's auth record
- Auto-confirm any user

**Remediation:**
Add role checks at the start of each function:
```sql
-- Add to the beginning of each privileged function:
IF NOT EXISTS (
  SELECT 1 FROM staff
  WHERE user_id = auth.uid() AND role = 'receptionist' AND is_active = true
) THEN
  RAISE EXCEPTION 'Only receptionists can perform this action';
END IF;
```

Apply to: `create_staff_auth`, `reset_staff_password`, `delete_staff_auth`, `auto_confirm_user`.

---

### H3. Overly Permissive RLS Policies

**Severity:** HIGH
**Files:**
- `supabase/migrations/001_initial_schema.sql:185` (`room_notes_insert` — `WITH CHECK (true)`)
- `supabase/migrations/001_initial_schema.sql:195` (`activity_log_insert` — `WITH CHECK (true)`)
- `supabase/migrations/017_add_staff_schedules.sql:23-33` (ALL policies use `USING (true)`)
- `supabase/migrations/024_chat_messages_delete_policy.sql:1` (`chat_messages_delete` — `USING (true)`)
- `supabase/migrations/001_initial_schema.sql:224-231` (GRANTs give full CRUD to all tables)

**Description:**
Multiple tables have no role-based authorization on write operations:
- `staff_schedules`: Any authenticated user can INSERT/UPDATE/DELETE any schedule
- `room_notes`: Any authenticated user can insert notes for any room
- `chat_messages`: Any authenticated user can delete any message
- `activity_log`: Any authenticated user can insert/modify audit entries

**Impact:** Cleaners can modify other staff's schedules, delete any chat message, or tamper with the audit trail.

**Remediation:**

`staff_schedules`:
```sql
-- Receptionists manage all schedules
CREATE POLICY "staff_schedules_insert_receptionist" ON staff_schedules
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'receptionist')
  );
CREATE POLICY "staff_schedules_update_receptionist" ON staff_schedules
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'receptionist')
  );
CREATE POLICY "staff_schedules_delete_receptionist" ON staff_schedules
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'receptionist')
  );
-- Staff can read all schedules (keep SELECT as is)
```

`room_notes`:
```sql
CREATE POLICY "room_notes_insert" ON room_notes FOR INSERT TO authenticated WITH CHECK (
  staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
```

`chat_messages`:
```sql
DROP POLICY "chat_messages_delete" ON chat_messages;
CREATE POLICY "chat_messages_delete" ON chat_messages FOR DELETE TO authenticated USING (
  sender_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'receptionist')
);
```

`activity_log`:
```sql
-- Remove DELETE grant from authenticated, make it admin-only or read-only
REVOKE DELETE ON activity_log FROM authenticated;
-- Remove INSERT policy for anon-like access
DROP POLICY IF EXISTS "activity_log_insert" ON activity_log;
CREATE POLICY "activity_log_insert" ON activity_log FOR INSERT TO authenticated WITH CHECK (
  staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
```

---

### H4. Client-Side-Only Authorization

**Severity:** HIGH
**Files:**
- `lib/app/login/login_page.dart:102-107` (role check determines navigation only)
- `lib/services/auth_service.dart:21` (`isAdmin` is client-side only)

**Description:**
Role-based access control is enforced entirely on the client side. After login, the app checks the user's role and navigates to either `/admin/overview` or `/staff/home/staff_dashboard`. However, there is no server-side middleware or Supabase function that checks whether a caller is authorized for the action they're performing.

**Impact:** A cleaner can craft HTTP requests (via Postman, curl, or a modified app) to call admin-only RPCs and perform admin operations.

**Remediation:**
This is addressed by H2 (role checks in SECURITY DEFINER functions) and H3 (role-based RLS policies). Additionally:
1. Ensure all admin-only operations go through RPCs with role checks, not just RLS.
2. Consider adding a `user_role` claim to the JWT via a Supabase hook or Edge Function so RLS can check it efficiently without querying the `staff` table on every request.
3. Do NOT rely on client-side navigation as the sole authorization mechanism.

---

## MEDIUM-HIGH Findings

### MH1. No Password Complexity Requirements

**Severity:** MEDIUM-HIGH
**Files:**
- `lib/app/staff/settings/change_password_page.dart:147-148`
- `lib/app/login/login_page.dart:198-202`

**Description:**
The only password validation is a 6-character minimum. Users can set passwords like `aaaaaa` or `123456`.

**Remediation:**
Update the validator in `change_password_page.dart`:
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) return 'Please enter a new password';
  if (value.trim().length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
  if (!RegExp(r'[a-z]').hasMatch(value)) return 'Include at least one lowercase letter';
  if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
  return null;
},
```

---

### MH2. No Login Rate Limiting

**Severity:** MEDIUM-HIGH
**Files:**
- `lib/app/login/login_page.dart:49-118`

**Description:**
The login form allows unlimited password attempts with no delay, cooldown, or lockout mechanism.

**Remediation (Client-side):**
1. Add an attempt counter with exponential backoff:
```dart
int _loginAttempts = 0;
static const int _maxAttempts = 5;
static const int _lockoutSeconds = 30;

// In _login():
if (_loginAttempts >= _maxAttempts) {
  setState(() => _error = 'Too many attempts. Please wait $_lockoutSeconds seconds.');
  return;
}
```
2. After failed attempt, increment `_loginAttempts` and start a cooldown timer.
3. **Note:** Supabase has server-side rate limiting on auth endpoints (default: 30 requests/minute per IP), but explicit client-side limiting is still recommended for UX.

---

### MH3. Sensitive Data Logged via debugPrint

**Severity:** MEDIUM-HIGH
**Files:**
- `lib/services/auth_service.dart:122` (logs full signup response)
- `lib/services/auth_service.dart:142` (logs staff-to-user linking)
- `lib/services/chat_service.dart:140` (logs chat message content in activity)
- `lib/services/notification_service.dart:42` (logs notification payload)
- Multiple other service files

**Description:**
`debugPrint` is used extensively. While Flutter strips `debugPrint` in release builds by default, this is not guaranteed if a custom logging framework is introduced, and it creates bad habits.

**Remediation:**
1. Enable the `avoid_print` lint in `analysis_options.yaml`:
```yaml
linter:
  rules:
    avoid_print: true
```
2. Replace `debugPrint` calls with a proper logging utility that can be disabled in release builds:
```dart
class Log {
  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }
  static void error(String message) { /* only in debug */ }
}
```
3. Specifically remove `debugPrint('Signup response: $result')` at `auth_service.dart:122` — this logs potentially sensitive user data.

---

## MEDIUM Findings

### M1. Unencrypted SQLite Cache

**Severity:** MEDIUM
**Files:**
- `lib/services/database_helper.dart:24`
- `lib/services/chat_service.dart:271-279`
- `lib/services/room_service.dart:362-378`

**Description:**
The local SQLite database `housekeeping.db` stores room data, chat messages (including sender names and content), and room types/floors in plaintext. On a rooted/jailbroken device, an attacker can read this data.

**Remediation:**
1. **Short-term:** Limit what is cached. Remove chat message content from the cache (cache only metadata like IDs and timestamps).
2. **Long-term:** Use `sqflite_common_ffi` with SQLCipher for encrypted storage, or use the `encrypt` package to encrypt sensitive fields before inserting.
3. For chat: consider not caching message content at all, or encrypting it with a device-derived key.

---

### M2. No Session Timeout / Auto-Logout

**Severity:** MEDIUM
**Files:**
- `lib/app/splash/splash_page.dart:41`

**Description:**
There is no session timeout or auto-logout mechanism. If a device is left unattended, the session remains valid until the JWT expires (Supabase default: 1 hour for access token, 7 days for refresh token).

**Remediation:**
1. Implement an idle timer that signs out the user after a configurable period (e.g., 15 minutes).
2. Store the last activity timestamp in memory and check it periodically.
3. Consider using `supabase_flutter`'s `onAuthStateChange` to handle token refresh failures gracefully.

---

### M3. Chat Message Content in Activity Log

**Severity:** MEDIUM
**Files:**
- `lib/services/chat_service.dart:138-141`

**Description:**
When a chat message is sent, the full message content is stored in the `activity_log` details JSON:
```dart
await ActivityService().log(
  action: 'message_sent',
  details: {'content': content.trim()},
);
```
This duplicates the message content in a table that is readable by all authenticated users.

**Remediation:**
Remove the content from the activity log:
```dart
await ActivityService().log(
  action: 'message_sent',
  details: {'message_length': content.trim().length},
);
```

---

### M4. No Input Sanitization on Chat/Notes

**Severity:** MEDIUM
**Files:**
- `lib/services/chat_service.dart:130`
- `lib/services/assignment_service.dart:332-351`
- `lib/services/chatbot_service.dart:212-221`

**Description:**
User input is passed to Supabase with only `.trim()`. While Supabase's PostgREST API parameterizes queries (preventing SQL injection), there is no content sanitization for XSS or content injection.

**Remediation:**
1. Add a content length limit (e.g., 5000 characters max for chat messages, 2000 for notes).
2. Strip or escape HTML tags if the content will ever be rendered in a WebView or web context.
3. For the Flutter app (native rendering), XSS is less of a risk, but content limits prevent abuse.

---

## LOW Findings

### L1. `.gitignore` Missing `.env` Pattern

**Severity:** LOW
**File:** `.gitignore`

**Description:** The `.gitignore` does not include a `.env` pattern. If someone creates a `.env` file in the future, it could be accidentally committed.

**Remediation:** Add to `.gitignore`:
```
.env
.env.*
!.env.example
```

---

### L2. `avoid_print` Lint Disabled

**Severity:** LOW
**File:** `analysis_options.yaml:24`

**Description:** The `avoid_print` rule is commented out, meaning there's no static analysis guard against `print`/`debugPrint` statements.

**Remediation:** Uncomment:
```yaml
avoid_print: true
```

---

### L3. No CORS Configuration for Web Deployment

**Severity:** LOW (MEDIUM if deployed to web)
**Files:** (Missing)

**Description:** If the app is deployed as a web app, the Supabase anon key is visible in browser dev tools. Without CORS restrictions, cross-origin requests could be made.

**Remediation:** Configure Supabase CORS settings in the Supabase dashboard to restrict allowed origins to the deployed domain.

---

## Remediation Priority & Migration Plan

### Phase 1: Critical Fixes (Do Immediately)

| # | Action | Files to Change | New Migration |
|---|--------|-----------------|---------------|
| 1 | Remove hardcoded admin seed | `002_...sql`, `006_...sql`, `plan.md` | `026_remove_hardcoded_admin.sql` |
| 2 | Secure temp password generation | `lib/services/auth_service.dart` | None (Dart only) |

### Phase 2: High-Priority Security (Do This Week)

| # | Action | Files to Change | New Migration |
|---|--------|-----------------|---------------|
| 3 | Add role checks to SECURITY DEFINER functions | `018_...sql`, `019_...sql`, `013_...sql` | `027_add_role_checks_to_rpcs.sql` |
| 4 | Scope anonymous staff access | `003_...sql`, `lib/services/auth_service.dart` | `028_scoped_login_view.sql` |
| 5 | Fix RLS policies for staff_schedules, room_notes, chat_messages, activity_log | Multiple migrations | `029_fix_rls_policies.sql` |

### Phase 3: Medium Priority (Do This Month)

| # | Action | Files to Change |
|---|--------|-----------------|
| 6 | Add password complexity requirements | `change_password_page.dart` |
| 7 | Add login rate limiting | `login_page.dart` |
| 8 | Remove debugPrint of sensitive data | Multiple service files |
| 9 | Enable `avoid_print` lint | `analysis_options.yaml` |
| 10 | Remove chat content from activity log | `chat_service.dart` |
| 11 | Add content length limits | `chat_service.dart`, `assignment_service.dart` |
| 12 | Add `.env` to `.gitignore` | `.gitignore` |

### Phase 4: Long-Term Improvements

| # | Action | Notes |
|---|--------|-------|
| 13 | Implement idle auto-logout | Add configurable session timeout |
| 14 | Encrypt local SQLite cache | Evaluate SQLCipher or field-level encryption |
| 15 | Add JWT role claims | Reduce DB lookups in RLS policies |
| 16 | Configure CORS for web deployment | If deploying to web |

---

## Migration File Naming Convention

Following the existing pattern (001-025, with 022 skipped), new migrations should be:
- `026_remove_hardcoded_admin.sql`
- `027_add_role_checks_to_rpcs.sql`
- `028_scoped_login_view.sql`
- `029_fix_rls_policies.sql`

---

## Testing Checklist

After implementing fixes:
- [ ] Verify admin can no longer be seeded with `admin123`
- [ ] Verify temp passwords are 16+ chars with mixed character classes
- [ ] Verify a cleaner cannot call `create_staff_auth`, `reset_staff_password`, `delete_staff_auth`, or `auto_confirm_user`
- [ ] Verify unauthenticated requests cannot enumerate staff emails or user IDs
- [ ] Verify a cleaner cannot modify another staff's schedule
- [ ] Verify a cleaner cannot delete another user's chat message
- [ ] Verify activity log entries cannot be deleted by non-admins
- [ ] Verify password change enforces complexity requirements
- [ ] Verify login locks out after 5 failed attempts
- [ ] Verify no sensitive data appears in debugPrint output
- [ ] Run `flutter analyze` with `avoid_print: true` and fix all warnings
