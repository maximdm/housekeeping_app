# Three-Role System + Keep Me Logged In

## 1. Overview

Add a `manager` role to create three access tiers:
- **Manager** - full admin (hotel structure, staff, everything)
- **Receptionist** - operational admin (overview, assignments, notes, chat; no staff/hotel config editing)
- **Cleaner** - mobile task interface (unchanged)

Add a "Keep me logged in" checkbox on the login page for **all roles**. If unchecked, session clears on app close.

---

## 2. Database Migration

### 2.1 Enum Change

```sql
ALTER TYPE staff_role ADD VALUE 'manager';
```

> Note: PostgreSQL does not allow removing values from an enum. The existing `receptionist` value stays in the enum but is only used for the receptionist role. The seed data switches the admin account to `manager`.

### 2.2 RLS Policy Updates

**Drop existing policies that need replacing:**

```sql
-- Drop old hotel structure policies (will be re-created for manager only)
DROP POLICY IF EXISTS "rooms_insert" ON rooms;
DROP POLICY IF EXISTS "rooms_update" ON rooms;
DROP POLICY IF EXISTS "rooms_delete" ON rooms;
DROP POLICY IF EXISTS "room_types_insert" ON room_types;
DROP POLICY IF EXISTS "room_types_update" ON room_types;
DROP POLICY IF EXISTS "floors_insert" ON floors;
DROP POLICY IF EXISTS "staff_insert" ON staff;
DROP POLICY IF EXISTS "staff_update" ON staff;
DROP POLICY IF EXISTS "staff_delete" ON staff;

-- Drop old assignment policies (will be re-created for manager + receptionist)
DROP POLICY IF EXISTS "room_assignments_insert" ON room_assignments;
DROP POLICY IF EXISTS "room_assignments_update" ON room_assignments;
```

**Create new policies - Hotel structure (manager only):**

```sql
-- Rooms: manager only for writes
CREATE POLICY "rooms_insert" ON rooms FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_update" ON rooms FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_delete" ON rooms FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Room types: manager only
CREATE POLICY "room_types_insert" ON room_types FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "room_types_update" ON room_types FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Floors: manager only
CREATE POLICY "floors_insert" ON floors FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Staff management: manager only
CREATE POLICY "staff_insert" ON staff FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "staff_update" ON staff FOR UPDATE TO authenticated USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);
CREATE POLICY "staff_delete" ON staff FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);
```

**Create new policies - Operations (manager + receptionist):**

```sql
-- Room assignments: manager and receptionist
CREATE POLICY "room_assignments_insert" ON room_assignments FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role IN ('manager', 'receptionist'))
);
CREATE POLICY "room_assignments_update" ON room_assignments FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role IN ('manager', 'receptionist'))
);
```

### 2.3 Seed Data Update

```sql
-- Change admin from receptionist to manager
UPDATE staff SET role = 'manager' WHERE name = 'Admin';
```

### 2.4 Cleanup

```sql
-- Remove unused function (Dart uses HTTP signup instead)
DROP FUNCTION IF EXISTS create_staff_auth(UUID, TEXT, TEXT);
```

### 2.5 Complete Migration SQL (copy-paste ready)

```sql
-- Migration: Add manager role + update RLS policies
-- Run: supabase db reset (or paste into SQL Editor)

-- 1. Add manager to enum
ALTER TYPE staff_role ADD VALUE 'manager';

-- 2. Drop old policies
DROP POLICY IF EXISTS "rooms_insert" ON rooms;
DROP POLICY IF EXISTS "rooms_update" ON rooms;
DROP POLICY IF EXISTS "rooms_delete" ON rooms;
DROP POLICY IF EXISTS "room_types_insert" ON room_types;
DROP POLICY IF EXISTS "room_types_update" ON room_types;
DROP POLICY IF EXISTS "floors_insert" ON floors;
DROP POLICY IF EXISTS "staff_insert" ON staff;
DROP POLICY IF EXISTS "staff_update" ON staff;
DROP POLICY IF EXISTS "staff_delete" ON staff;
DROP POLICY IF EXISTS "room_assignments_insert" ON room_assignments;
DROP POLICY IF EXISTS "room_assignments_update" ON room_assignments;

-- 3. Hotel structure policies (manager only)
CREATE POLICY "rooms_insert" ON rooms FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_update" ON rooms FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_delete" ON rooms FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "room_types_insert" ON room_types FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "room_types_update" ON room_types FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "floors_insert" ON floors FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "staff_insert" ON staff FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "staff_update" ON staff FOR UPDATE TO authenticated USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);
CREATE POLICY "staff_delete" ON staff FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);

-- 4. Operations policies (manager + receptionist)
CREATE POLICY "room_assignments_insert" ON room_assignments FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role IN ('manager', 'receptionist'))
);
CREATE POLICY "room_assignments_update" ON room_assignments FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role IN ('manager', 'receptionist'))
);

-- 5. Update admin seed
UPDATE staff SET role = 'manager' WHERE name = 'Admin';

-- 6. Cleanup unused function
DROP FUNCTION IF EXISTS create_staff_auth(UUID, TEXT, TEXT);
```

---

## 3. Dart Changes

### 3.1 Add `manager` to StaffRole enum

**File:** `lib/models/staff_member.dart`

Add `manager` value and update switch statements:

```dart
enum StaffRole {
  cleaner,
  receptionist,
  manager;

  String get label {
    switch (this) {
      case StaffRole.cleaner:
        return 'Cleaner';
      case StaffRole.receptionist:
        return 'Receptionist';
      case StaffRole.manager:
        return 'Manager';
    }
  }

  factory StaffRole.fromString(String value) {
    return StaffRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaffRole.cleaner,
    );
  }
}
```

### 3.2 Update AuthService role getters

**File:** `lib/services/auth_service.dart`

```dart
StaffRole? get userRole => _currentStaff?.role;
bool get isAdmin => userRole == StaffRole.receptionist || userRole == StaffRole.manager;
bool get isManager => userRole == StaffRole.manager;
bool get isCleaner => userRole == StaffRole.cleaner;
```

### 3.3 Login Page - Checkbox + Routing

**File:** `lib/app/login/login_page.dart`

Add state variable:
```dart
bool _keepLoggedIn = true; // default checked
```

In the form, after the password field, add checkbox:
```dart
const SizedBox(height: 12),
Row(
  children: [
    Checkbox(
      value: _keepLoggedIn,
      onChanged: (v) => setState(() => _keepLoggedIn = v ?? true),
    ),
    const Text('Keep me logged in'),
  ],
),
```

In `_login()` method, after successful sign-in, save preference:
```dart
import 'package:shared_preferences/shared_preferences.dart';

// After successful login, before navigation:
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('keepLoggedIn_${user.id}', _keepLoggedIn);
```

Update routing to handle manager:
```dart
final role = data['role'] as String;
if (role == 'receptionist' || role == 'manager') {
  Routefly.navigate('/admin/overview');
} else {
  Routefly.navigate('/staff/home/staff_dashboard');
}
```

### 3.4 Splash Page - Keep-Logged-In Check

**File:** `lib/app/splash/splash_page.dart`

After session check passes and user is found, add:
```dart
import 'package:shared_preferences/shared_preferences.dart';

// After fetching role, before routing:
final prefs = await SharedPreferences.getInstance();
final keepLoggedIn = prefs.getBool('keepLoggedIn_${user.id}') ?? true;

if (!keepLoggedIn) {
  await Supabase.instance.client.auth.signOut();
  Routefly.navigate('/login');
  return;
}
```

Update routing:
```dart
final role = data['role'] as String;
if (role == 'receptionist' || role == 'manager') {
  Routefly.navigate('/admin/overview');
} else {
  Routefly.navigate('/staff/home/staff_dashboard');
}
```

### 3.5 Change Password Page

**File:** `lib/app/staff/settings/change_password_page.dart`

Update `_detectHomeRoute()`:
```dart
_homeRoute = (staffData != null && (staffData['role'] == 'receptionist' || staffData['role'] == 'manager'))
    ? '/admin/overview'
    : '/staff/home/staff_dashboard';
```

### 3.6 AdminLayout - Filter Nav by Role

**File:** `lib/layouts/admin_layout.dart`

Add parameter:
```dart
class AdminLayout extends StatelessWidget {
  final bool isFullAdmin;
  // ...
  const AdminLayout({
    // ...
    this.isFullAdmin = true,
  });
```

Filter nav items in the build method or as a computed property:
```dart
List<_NavItem> get _visibleNavItems {
  if (isFullAdmin) return _navItems; // all 6 items
  return _navItems.where((item) =>
    item.route != '/admin/rooms' &&
    item.route != '/admin/staff'
  ).toList(); // 4 items: Overview, Chat, Notes, AI Chat
}
```

Replace `_navItems` references with `_visibleNavItems` in sidebar, bottom nav, and `_selectedIndex`.

Each page that uses `AdminLayout` needs to pass `isFullAdmin`:
- Staff/admin pages query the role and pass `isFullAdmin: role == 'manager'`
- Or use `AuthService` if available in context

### 3.7 Staff Page - Hide Edit for Receptionist

**File:** `lib/app/admin/staff/staff_page.dart`

- Hide FAB (`floatingActionButton`) when not full admin
- Hide "Add Staff" button when not full admin
- Hide `PopupMenuButton` (edit/deactivate/delete) when not full admin
- Detection: query role in `initState` and store as `_isFullAdmin`

### 3.8 Staff Form - Role Guard

**File:** `lib/app/admin/staff/staff_form_page.dart`

In `initState` or build, check role and redirect if receptionist:
```dart
// Redirect receptionists away
if (!_isFullAdmin) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Routefly.navigate('/admin/overview');
  });
  return const SizedBox();
}
```

### 3.9 Rooms Page - Hide Edit for Receptionist

**File:** `lib/app/admin/rooms/rooms_page.dart`

Same pattern as staff page:
- Hide FAB when not full admin
- Hide room edit/delete actions when not full admin

### 3.10 Room Form - Role Guard

**File:** `lib/app/admin/rooms/room_form_page.dart`

Same pattern as staff form - redirect receptionists.

### 3.11 Chatbot Service

**File:** `lib/services/chatbot_service.dart`

In `_activeStaff()`, add manager to role groupings:
```dart
// Add 'manager' alongside 'receptionist' in any role-based filtering
```

### 3.12 Chat Message Model

**File:** `lib/models/chat_message.dart`

Update default and display logic to handle `StaffRole.manager`.

### 3.13 Admin Chat Page

**File:** `lib/app/admin/chat/admin_chat_page.dart`

Manager messages get primary bubble color (same as receptionist):
```dart
if (message.senderRole == StaffRole.receptionist || message.senderRole == StaffRole.manager) {
  // primary color bubble
}
```

### 3.14 Chat Page (shared)

**File:** `lib/app/shared/chat/chat_page.dart`

Same bubble color update for manager role.

---

## 4. Files Modified (14 total)

| # | File | Change |
|---|------|--------|
| 1 | `supabase/migrations/001_initial_schema.sql` | Enum + RLS + seed |
| 2 | `lib/models/staff_member.dart` | Add `manager` enum value |
| 3 | `lib/services/auth_service.dart` | `isManager` getter |
| 4 | `lib/app/login/login_page.dart` | Checkbox + routing |
| 5 | `lib/app/splash/splash_page.dart` | Keep-logged-in check + routing |
| 6 | `lib/app/staff/settings/change_password_page.dart` | Home route |
| 7 | `lib/layouts/admin_layout.dart` | `isFullAdmin` + filtered nav |
| 8 | `lib/app/admin/staff/staff_page.dart` | Hide edit for receptionist |
| 9 | `lib/app/admin/staff/staff_form_page.dart` | Role guard |
| 10 | `lib/app/admin/rooms/rooms_page.dart` | Hide edit for receptionist |
| 11 | `lib/app/admin/rooms/room_form_page.dart` | Role guard |
| 12 | `lib/services/chatbot_service.dart` | Manager in role groups |
| 13 | `lib/models/chat_message.dart` | Manager bubble color |
| 14 | `lib/app/admin/chat/admin_chat_page.dart` + `lib/app/shared/chat/chat_page.dart` | Manager bubble color |

---

## 5. Security Summary

- **RLS** is the primary security layer - unauthorized DB writes are rejected at the database level regardless of UI
- **UI gating** hides features receptionists shouldn't see - purely UX, not security
- **"Keep me logged in"** gives each user control over their session persistence via `SharedPreferences`
- **No route guards** - RLS + UI hiding is sufficient; can add later if needed
- **Manager session** persists only if checkbox is checked; defaults to checked for backward compatibility
