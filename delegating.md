# Delegating & Schedule Enhancement Plan

## Overview

Two major feature sets:

1. **Enhanced Schedule** — assign whole floors and individual rooms to staff per date, with recurring patterns
2. **Notes Tabs & Sharing** — "My Notes" / "Received Notes" tabs with unread tracking, and multi-person sharing on all note types

---

## Part 1: Enhanced Schedule with Floor/Room Assignment

### Database

**Extend `room_assignments`:**
```sql
ALTER TABLE room_assignments
  ADD COLUMN assignment_date DATE,
  ADD COLUMN floor_id UUID REFERENCES floors(id) ON DELETE SET NULL;
```
- `assignment_date = NULL` → permanent/ongoing (backward compatible)
- `assignment_date = '2026-07-22'` → specific date
- `floor_id` set → came from a floor assignment (for bulk unassign)
- Index on `(assignment_date, staff_id)` for fast date queries

**New `recurring_schedules` table:**
```sql
CREATE TABLE recurring_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  floor_id UUID REFERENCES floors(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (floor_id IS NOT NULL OR room_id IS NOT NULL)
);
```
- 0=Monday, 6=Sunday
- One row per recurring pattern (e.g., "Staff A → Floor 1 → Every Monday")

### Conflict Resolution

Last assignment wins:
- Staff A has Floor 1 → Staff B gets Room 104 → Staff A keeps Floor 1 minus Room 104
- When assigning a floor: skip rooms individually assigned to someone else for that date
- When assigning an individual room: overwrite any existing assignment (floor or individual) for that room/date

### Backend (`AssignmentService` additions)

- `assignFloor(floorId, staffId, DateTime date)` — queries rooms on floor, skips individually assigned rooms, inserts `room_assignments` rows with `floor_id` and `assignment_date`
- `unassignFloor(floorId, staffId, DateTime date)` — deletes all `room_assignments` where `floor_id = X AND staff_id = Y AND assignment_date = D`
- `loadAssignmentsForDate(DateTime date)` — loads all active assignments for a specific date (merges recurring + specific)
- `loadMyAssignmentsForDate(String staffId, DateTime date)` — staff-facing: today's rooms
- `assignRecurring(staffId, {floorId, roomId}, int dayOfWeek)` — inserts into `recurring_schedules`
- `removeRecurring(String recurringId)` — deletes a recurring pattern
- `loadRecurringSchedules(String staffId)` — loads all recurring patterns for a staff member
- Modify `assignRoom()` — add optional `DateTime? date` parameter
- Modify `loadMyAssignments()` — filter by `assignment_date = today OR assignment_date IS NULL`
- Extend `Assignment` model — add `assignmentDate`, `floorId` fields

**Assignment resolution logic:**
1. Load recurring patterns for the target day_of_week
2. Load specific-date assignments for the target date
3. Specific-date assignments override recurring patterns
4. Individual room assignments override floor assignments

### Admin UI — Enhanced Schedule Calendar

Modify `ScheduleCalendar` widget (`lib/widgets/schedule_calendar.dart`):

- Tapping a day shows an **assignment panel** below the calendar
- Calendar day cells with assignments get a small dot indicator
- Selected day gets highlighted background

**New `AssignmentPanel` widget** (`lib/widgets/assignment_panel.dart`):
- Shows selected date and staff member
- **"Assign Floor"** button → floor picker bottom sheet → calls `assignFloor()`
- **"Assign Room"** button → room picker bottom sheet → calls `roomAssignRoom(date: selectedDate)`
- Lists current assignments for that day (floor assignments grouped, individual rooms)
- Remove button per assignment/floor group
- **Recurring toggle** — "Make recurring for this day of week" checkbox on floor/room assignment

### Staff UI — Today's Assignments

- Modify `StaffDashboardPage` — call `loadMyAssignmentsForDate(staffId, DateTime.now())`
- Show floor grouping headers: "Floor 1 — 3 rooms", "Floor 2 — 2 rooms"
- Individual rooms listed under each floor group
- Modify `StaffRoomsPage` — same date-based loading

### Activity Logging

New actions: `floor_assigned`, `floor_unassigned`, `recurring_assigned`, `recurring_removed`

---

## Part 2: Notes Tabs & Sharing System

### Database

**New `note_shares` table:**
```sql
CREATE TABLE note_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_type TEXT NOT NULL CHECK (note_type IN ('room_note', 'todo')),
  note_id UUID NOT NULL,
  shared_with UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  shared_by UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(note_type, note_id, shared_with)
);
```
- Polymorphic: `note_type` = `'room_note'` → `note_id` references `room_notes.id`
- `note_type` = `'todo'` → `note_id` references `personal_todos.id`
- `is_read` tracks unread state
- `shared_by` tracks who shared it

**RLS:**
- SELECT: users can see shares where `shared_with` matches their staff ID, or where they are the author
- INSERT/UPDATE/DELETE: only the original author or manager

**Indexes:**
- `(note_type, note_id)` for fast lookups
- `(shared_with, is_read)` for unread count queries

### Notes Page — Two Tabs

Replace single `ListView` with `TabBar` + `TabBarView`:

**Tab 1: "My Notes"**
- Room notes I authored (existing `_notes`)
- My personal todos (existing `_todos`)
- Same card rendering, grouped under this tab

**Tab 2: "Received Notes"**
- Notes/todos shared with me via `note_shares`
- Blue dot indicator if `is_read == false`
- Tapping marks as read (`is_read = true`)
- Shows author name and which room/todo it belongs to
- Replaces the "Forwarded to me" section

**Unread badge:** "Received Notes" tab label shows count badge (e.g., `Received (3)`) when unread shares exist.

### Sharing in Create/Edit Dialogs

**Add Room Note dialog** — "Share with" section after status chips:
- Radio: **None** (default) / **All staff** / **Custom**
- When "Custom" selected: checklist of all active staff members
- "None" for room notes = only room's assigned staff can see it (existing behavior)

**Edit Room Note dialog** — same "Share with" section, pre-populated with current shares

**Create To-Do dialog** (single and list) — same "Share with" section:
- **None** (default) / **All staff** / **Custom** with staff checklist

**Sharing flow:**
1. User fills title, content, status, room (if room note)
2. Expands "Share with" → picks staff members
3. `addNote()` inserts into `room_notes` or `personal_todos`
4. `shareNote()` inserts rows into `note_shares` for each selected staff

### Backend (`AssignmentService` additions)

```dart
Future<void> shareNote({
  required String noteType,   // 'room_note' or 'todo'
  required String noteId,
  required List<String> sharedWithStaffIds,
  required String sharedByStaffId,
})

Future<void> unshareNote({
  required String noteType,
  required String noteId,
})

Future<List<SharedNote>> loadReceivedNotes(String staffId)

Future<void> markAsRead(String noteType, String noteId, String staffId)

Future<int> getUnreadCount(String staffId)

Future<void> updateShares({
  required String noteType,
  required String noteId,
  required List<String> newStaffIds,
  required String sharedByStaffId,
})
```

### New Model: `SharedNote` (`lib/models/shared_note.dart`)

```dart
class SharedNote {
  final String noteId;
  final String noteType;       // 'room_note' or 'todo'
  final bool isRead;
  final String sharedByName;
  final String? roomNumber;    // if room_note
  final String? noteTitle;
  final String? noteContent;
  final String? noteStatus;    // if room_note
  final DateTime sharedAt;
}
```

### UI Details

**Tab bar:** Red accent indicator (app theme). Unread count badge on "Received Notes" tab.

**Received note card:**
- Same design as existing note cards
- Blue unread dot next to status badge
- "Shared by: {author name}" subtitle
- Tapping marks as read and navigates to room/todo

**Sharing section in dialogs:**
- Collapsible "Share with" section (expandable via tap)
- Default collapsed showing "Share with: None"
- When expanded: radio buttons (None / All / Custom) + staff checklist when Custom selected
- Each staff member shows name + role badge

**Existing forwarding:**
- Forward icon stays on note cards (backward compatibility)
- "Forwarded to me" section removed — replaced by "Received Notes" tab
- Forwarding now uses `note_shares` table internally

---

## File Changes Summary

| File | Change |
|---|---|
| `supabase/migrations/002_schedule_and_notes.sql` | New migration: `room_assignments` alterations, `recurring_schedules`, `note_shares` |
| `lib/models/shared_note.dart` | New model |
| `lib/services/assignment_service.dart` | Major additions: floor/recurring assignment, sharing, received notes, unread |
| `lib/services/schedule_service.dart` | Add assignment integration |
| `lib/widgets/schedule_calendar.dart` | Rewrite: assignment panel integration |
| `lib/widgets/assignment_panel.dart` | New widget: floor/room assignment UI |
| `lib/widgets/sharing_section.dart` | New widget: "Share with" checkboxes |
| `lib/app/admin/staff/staff_page.dart` | Pass extra services to calendar |
| `lib/app/staff/home/staff_dashboard_page.dart` | Date-based loading, floor grouping |
| `lib/app/staff/home/staff_rooms_page.dart` | Date-based loading |
| `lib/app/shared/notes/notes_page.dart` | Major rewrite: tabs, received notes, sharing in dialogs |

---

## Implementation Order

1. Database migration (all schema changes in one file)
2. Backend models (`SharedNote`, extended `Assignment`)
3. Backend services (assignment + sharing methods)
4. Schedule calendar + assignment panel
5. Staff dashboard date-based loading
6. Notes page tabs + received notes view
7. Sharing section widget + integration in create/edit dialogs
8. Activity logging for new actions
9. `flutter analyze` + manual testing
