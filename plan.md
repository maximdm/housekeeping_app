# Housekeeping App — Project Plan

## Overview
A dual-role Flutter application for hotel housekeeping management. Admin dashboard for management, mobile staff app for cleaners, backed by Supabase with offline support via sqflite.

---

## Tech Stack
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart 3+) |
| Routing | routefly v3.1.3 |
| Backend | Supabase (auth, database, realtime) |
| Local DB | sqflite (offline cache) |
| UI | forui v0.24.0 (red accents, minimalist) |
| Notifications | flutter_local_notifications |

---

## Database Schema
See `supabase/migrations/001_initial_schema.sql`

**Tables:** rooms, room_types, floors, staff, room_assignments, room_notes, chat_messages, activity_log

**Enums:** room_status (dirty/in_progress/clean), staff_role (cleaner/receptionist)

**Auth:** Email/password with fake internal emails. Admin seed: `admin@hotel.local` / `admin123`. Staff limit: 35 accounts.

---

## Phases

### Phase 1 — Foundation ✅
- [x] Delete dead `app.dart` and stale test
- [x] Initialize Supabase in `main()`
- [x] Configure forui theme (red accents)
- [x] Create database schema with RLS, grants, realtime
- [x] Set up routefly routing structure

### Phase 1.5 — Cleanup & Bug Fixes ✅
- [x] `rooms_page.dart:85` — `DropdownButtonFormField` uses `initialValue` (correct for Flutter ≥3.33, `value` is deprecated)
- [x] Move inline `Room`, `RoomStatus` models from `rooms_page.dart` to `lib/models/room.dart`
- [x] Move inline `StaffMember`, `StaffStatus` models from `staff_page.dart` to `lib/models/staff_member.dart`
- [x] Add `StaffRole` enum (cleaner/receptionist) to `staff_member.dart`
- [x] Add `fromJson`/`toJson` serialization to all models
- [x] Remove unused packages (`security_plus`, `sonner_flutter`)
- [x] Replace placeholder `test/widget_test.dart` with real model unit tests (8 tests passing)

### Phase 2 — Auth & Navigation Shell ✅
**Goal:** Users can log in. Admin has sidebar. Staff has bottom nav.

- [x] **AuthService** (`lib/services/auth_service.dart`)
  - `signInWithOTP(phone)` — sends OTP via Supabase Auth
  - `verifyOTP(phone, token)` — verifies the OTP code
  - `signOut()` — clears session
  - `getCurrentUser()` — returns current `User?`
  - `getUserRole()` — queries `staff` table for `staff_role` enum value
  - `onAuthStateChange()` — stream of auth state changes
- [x] **Login page** (`lib/app/login/login_page.dart`)
  - Phone number input field
  - "Send Code" button → calls `signInWithOTP`
  - OTP verification input → calls `verifyOTP`
  - Loading/error states
- [x] **Splash page** update (`lib/app/splash/splash_page.dart`)
  - Check real `Supabase.instance.client.auth.currentSession`
  - If no session → navigate to `/login`
  - If session exists → fetch role from `staff` table
  - Route to `/admin/overview` or `/staff/home/staff_dashboard` based on role
- [x] **Admin navigation shell** (`lib/app/admin/admin_layout.dart`)
  - `StatefulWidget` with `LayoutBuilder`
  - Desktop (≥800px): persistent `NavigationRail` sidebar
  - Mobile (<800px): `Drawer` hamburger menu
  - Sidebar items: Overview, Rooms, Staff, Chat
  - Highlights current route, handles navigation via `Routefly.navigate()`
- [x] **Staff navigation shell** (`lib/app/staff/staff_layout.dart`)
  - `BottomNavigationBar` with 2 tabs: Tasks, Chat
  - Mobile-first, persistent bottom nav
  - Highlights active tab based on current route
- [x] **Role-based route guards**
  - Splash page acts as the auth gate
  - Unauthenticated users always redirected to `/login`
  - Admin routes inaccessible to staff, and vice versa

**Files to create/modify:**
- `lib/services/auth_service.dart` (create)
- `lib/app/login/login_page.dart` (create)
- `lib/app/splash/splash_page.dart` (modify — real auth check)
- `lib/app/admin/admin_layout.dart` (create)
- `lib/app/staff/staff_layout.dart` (create)

### Phase 3 — Room Management ✅
**Goal:** Admin can define room types, floors, and rooms with real Supabase data.

- [x] **Models** (separate files)
  - `Room` — id, number, room_type_id, floor_id, status (enum), joined room_type/floor data
  - `RoomType` — id, name, description
  - `Floor` — id, number, name
  - All with `fromJson` factory constructors and `toJson` methods
- [x] **RoomService** (`lib/services/room_service.dart`)
  - `loadRooms()` — fetches rooms with joined room_type and floor data
  - `loadRoomTypes()` / `loadFloors()` — reference data
  - `createRoom()` / `updateRoom()` / `deleteRoom()` — CRUD operations
  - `updateRoomStatus()` — status change with real-time notify
  - `createRoomType()` / `deleteRoomType()` — room type CRUD
  - `createFloor()` — floor creation
  - `filterRooms()` — filter by floor, status, room type
  - `subscribeToChanges()` — real-time via Supabase Realtime
- [x] **Offline caching** (sqflite via `database_helper.dart`)
  - Cache rooms, room_types, floors tables locally
  - Serve from cache when Supabase is unreachable
  - Auto-sync on reconnect
- [x] **Real-time updates**
  - Subscribe to `rooms` table changes via Supabase Realtime
  - Update UI instantly when room status changes
- [x] **Wire up admin rooms page**
  - Real data from `RoomService` replacing mock data
  - Filter bar: by floor, status, room type
  - Room table with status change, edit, delete actions
  - `room_form_page.dart` for add/edit with dropdowns

**Files to create/modify:**
- `lib/models/room.dart` (create)
- `lib/models/room_type.dart` (create)
- `lib/models/floor.dart` (create)
- `lib/services/room_service.dart` (create)
- `lib/app/admin/rooms/rooms_page.dart` (modify — real data)
- `lib/app/admin/rooms/room_form_page.dart` (create)

### Phase 4 — Staff Management ✅
**Goal:** Admin can manage staff accounts (max 35, no email).

- [x] **StaffMember model** updated (`lib/models/staff_member.dart`)
  - id, user_id, name, role (StaffRole enum), phone, is_active, assigned_rooms
  - `status` derived from `isActive` (onShift/offShift)
- [x] **StaffService** (`lib/services/staff_service.dart`)
  - `loadStaff()` — fetches staff with room assignment counts
  - `addStaff()` — creates new staff, enforces 35-account limit
  - `updateStaff()` — update name, role, phone
  - `deactivateStaff()` / `activateStaff()` — toggle is_active
  - `deleteStaff()` — permanent delete
  - `canAddMore` / `staffCount` — limit enforcement helpers
- [x] **35 account limit enforcement**
  - Checked in `addStaff()` before insert
  - UI shows count (X/35) in AppBar
  - "Add Staff" button disabled when limit reached
  - Form shows warning and disables save button at limit
- [x] **Staff form page** (`lib/app/admin/staff/staff_form_page.dart`)
  - Name, phone (optional), role dropdown
  - Account limit indicator
  - Add/edit modes
- [x] **Wire up admin staff page**
  - Real data from `StaffService` replacing mock data
  - Responsive grid/list view
  - Edit profile, activate/deactivate actions

**Files to create/modify:**
- `lib/models/staff_member.dart` (create)
- `lib/services/staff_service.dart` (create)
- `lib/app/admin/staff/staff_page.dart` (modify — real data)
- `lib/app/admin/staff/staff_form_page.dart` (create)

### Phase 5 — Task Assignment & Room Status ✅
**Goal:** Admin assigns rooms, staff updates status in real-time.

- [x] **AssignmentService** (`lib/services/assignment_service.dart`)
  - `loadMyAssignments(staffId)` — fetches active assignments with room data
  - `assignRoom(roomId, staffId)` — creates assignment
  - `completeAssignment(assignmentId)` — marks assignment done
  - `updateRoomStatus(roomId, status)` — status change with activity logging
  - `addNote(roomId, staffId, content)` — add note to room
  - `loadNotes(roomId)` — fetch notes with staff names
  - `loadActivityLog(limit)` — recent activity feed
  - Internal `_logActivity()` — auto-logs actions to activity_log table
- [x] **Staff dashboard** (`lib/app/staff/home/staff_dashboard_page.dart`)
  - Shows today's assigned rooms as cards
  - Each card: room number, type, floor, current status
  - Tap to open room detail
  - Pull-to-refresh
  - Empty state when no assignments
- [x] **Room detail page** (`lib/app/staff/home/room_detail_page.dart`)
  - Room header with number, type, floor
  - Status change buttons: Dirty / In Progress / Clean
  - Notes section: view existing notes, add new note with send button
  - Success/error feedback via SnackBar
- [x] **Chat page** placeholder (`lib/app/shared/chat/chat_page.dart`)
  - Skeleton for Phase 6

**Files to create/modify:**
- `lib/services/assignment_service.dart` (create)
- `lib/app/staff/home/staff_dashboard_page.dart` (modify — real data)
- `lib/app/staff/home/room_detail_page.dart` (create)

### Phase 6 — Chat System ✅
**Goal:** Logged-in users can communicate in real-time.

- [x] **ChatMessage model** (`lib/models/chat_message.dart`)
  - id, sender_id, sender_name, sender_role, content, created_at
  - `fromJson` with nested sender data from staff join
- [x] **ChatService** (`lib/services/chat_service.dart`)
  - `loadMessages(limit)` — paginated message history
  - `loadMore()` — load older messages on scroll
  - `sendMessage(text)` — insert into chat_messages
  - `subscribeToChat()` — real-time via Supabase Realtime
  - Offline cache via sqflite (chat_cache table)
- [x] **Chat UI** (`lib/app/shared/chat/chat_page.dart`)
  - Message list with auto-scroll to bottom
  - Text input bar with send button
  - Sender name + role badge (color-coded: red for receptionist, blue for cleaner)
  - Date grouping (Today, Yesterday, older)
  - Pagination on scroll-up
  - Empty state when no messages

**Files to create/modify:**
- `lib/models/chat_message.dart` (create)
- `lib/services/chat_service.dart` (create)
- `lib/app/shared/chat/chat_page.dart` (create)

### Phase 7 — Overview Dashboard (Real Data) ✅
**Goal:** Admin overview shows live stats.

- [x] **Queries**
  - Room status counts: counts `clean`, `dirty`, `in_progress` from `rooms` table
  - Active staff count: count of `staff` where `is_active = true`
  - Recent activity feed: last 20 entries from `activity_log` with staff name join
- [x] **UI updates** (`lib/app/admin/overview/overview_page.dart`)
  - Real metric cards: Clean Rooms, Needs Cleaning, In Progress, Active Staff
  - Real Recent Activity feed with formatted timestamps and action text
  - Priority Attention card with dynamic alerts (dirty rooms, inactive staff)
  - Empty states when no data
- [x] **Pull-to-refresh** via `RefreshIndicator`
- [x] **Responsive layout** preserved (row for desktop, column for mobile)

**Files to create/modify:**
- `lib/app/admin/overview/overview_page.dart` (modify — real data)

### Phase 8 — Notifications ✅
- [x] `flutter_local_notifications` integration (`lib/services/notification_service.dart`)
- [x] Notifications for room assignments — shows staff name + room number
- [x] Status change alerts — shows new room status
- [x] Note added notifications — shows author name + room number
- [x] Notification tap handler (`onDidReceiveNotificationResponse`)
- [x] Init in `main.dart` after Supabase init
- [x] Android POST_NOTIFICATIONS permission in AndroidManifest.xml

### Phase 9 — AI Chatbot ✅
- [x] **ChatbotService** (`lib/services/chatbot_service.dart`)
  - Keyword-based natural language parser
  - Queries Supabase directly for room/staff/activity data
  - Supports: "rooms needing cleaning", "in progress", "clean rooms", "all rooms", "room 101", "staff", "activity", "floors"
  - Welcome message with help text
  - Chat history management
- [x] **AI Chat UI** (`lib/app/shared/chat/ai_chat_page.dart`)
  - Chat-style message list with auto-scroll
  - User messages (primary color) and bot messages (surface color)
  - Typing indicator while processing
  - Text input with send button
  - Clear chat history button
  - Markdown-style formatting in responses (bold, bullets)
- [x] **Navigation integration**
  - Admin sidebar: "AI Chat" item
  - Staff bottom nav: "AI" tab
  - Routes: `/admin/chatbot` and `/shared/ai_chat`
- [x] **Room detail queries** — fetches type, floor, status, and recent notes
- [x] **Floor grouping** — rooms grouped by floor with status icons

---

## File Structure (Target)
```
lib/
├── main.dart
├── main.g.dart                          (generated)
├── main.route.dart                      (generated)
├── models/
│   ├── room.dart
│   ├── room_type.dart
│   ├── floor.dart
│   ├── staff_member.dart
│   └── chat_message.dart
├── services/
│   ├── auth_service.dart
│   ├── room_service.dart
│   ├── staff_service.dart
│   ├── assignment_service.dart
│   ├── chat_service.dart
│   ├── notification_service.dart
│   └── chatbot_service.dart
├── app/
│   ├── splash/
│   │   └── splash_page.dart
│   ├── login/
│   │   └── login_page.dart
│   ├── admin/
│   │   ├── admin_layout.dart            (sidebar shell)
│   │   ├── overview/
│   │   │   └── overview_page.dart
│   │   ├── rooms/
│   │   │   ├── rooms_page.dart
│   │   │   └── room_form_page.dart
│   │   └── staff/
│   │       ├── staff_page.dart
│   │       └── staff_form_page.dart
│   ├── staff/
│   │   ├── staff_layout.dart            (bottom nav shell)
│   │   ├── home/
│   │   │   ├── staff_dashboard_page.dart
│   │   │   └── room_detail_page.dart
│   │   └── settings/
│   │       └── change_password_page.dart
│   └── shared/
│       └── chat/
│           ├── chat_page.dart
│           └── ai_chat_page.dart
```

---

## Running the App
```bash
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
```

**Setup:**
1. Run `supabase/migrations/002_auth_email_password.sql` in Supabase SQL Editor
2. This creates the admin account (`admin@hotel.local` / `admin123`) and helper functions
3. Admin creates staff accounts → system generates temp password → give to staff
4. Staff logs in with their name (from dropdown) + password

## Key Decisions
- **Email/password auth** with fake internal emails (`name_id@hotel.local`) — no real email needed
- **Admin account hardcoded** via SQL seed: `admin@hotel.local` / `admin123`
- **35 staff account limit** enforced in service layer
- **routefly** for routing (no Navigator.push, no go_router)
- **forui** for UI components (Material 3 fallback only when needed)
- **sqflite** for offline cache of rooms and chat
- **Supabase Realtime** for chat and room status sync
