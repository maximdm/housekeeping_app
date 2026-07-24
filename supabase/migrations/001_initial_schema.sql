-- Housekeeping App - Consolidated Schema
-- Single migration representing the complete database state

-- =============================================
-- ENUMS
-- =============================================

CREATE TYPE room_status AS ENUM ('dirty', 'in_progress', 'clean', 'skipped');
CREATE TYPE staff_role AS ENUM ('cleaner', 'receptionist', 'manager');

-- =============================================
-- TABLES
-- =============================================

CREATE TABLE room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  number TEXT NOT NULL UNIQUE,
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  number TEXT NOT NULL UNIQUE,
  room_type_id UUID NOT NULL REFERENCES room_types(id) ON DELETE RESTRICT,
  floor_id UUID NOT NULL REFERENCES floors(id) ON DELETE RESTRICT,
  status room_status NOT NULL DEFAULT 'dirty',
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  account_name TEXT NOT NULL UNIQUE,
  role staff_role NOT NULL DEFAULT 'cleaner',
  phone TEXT,
  login_email TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  on_shift BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE room_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'none' CHECK (status IN ('none', 'important', 'done', 'problem', 'delegate', 'today', 'tomorrow', 'this_week')),
  forwarded_to UUID REFERENCES staff(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE personal_todos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'single',
  is_done BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE todo_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  todo_id UUID NOT NULL REFERENCES personal_todos(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  is_done BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE staff_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  is_on_shift BOOLEAN NOT NULL DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(staff_id, date)
);

CREATE TABLE ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_user BOOLEAN NOT NULL,
  archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE note_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_type TEXT NOT NULL CHECK (note_type IN ('room_note', 'todo', 'staff_note')),
  note_id UUID NOT NULL,
  shared_with UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  shared_by UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(note_type, note_id, shared_with)
);

CREATE TABLE floor_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  floor_id UUID NOT NULL REFERENCES floors(id) ON DELETE CASCADE,
  assignment_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(staff_id, floor_id, assignment_date)
);

CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE staff_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  assignment_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(staff_id, shift_id, assignment_date)
);

CREATE TABLE staff_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_floor ON rooms(floor_id);
CREATE INDEX idx_chat_messages_created ON chat_messages(created_at DESC);
CREATE INDEX idx_staff_user_id ON staff(user_id);
CREATE INDEX idx_activity_log_created ON activity_log(created_at DESC);
CREATE INDEX idx_personal_todos_staff ON personal_todos(staff_id);
CREATE INDEX idx_todo_list_items_todo ON todo_list_items(todo_id);
CREATE INDEX idx_staff_schedules_staff_date ON staff_schedules(staff_id, date);
CREATE INDEX idx_staff_schedules_date ON staff_schedules(date);
CREATE INDEX idx_ai_chat_user_created ON ai_chat_messages(user_id, created_at DESC);
CREATE INDEX idx_ai_chat_user_archived ON ai_chat_messages(user_id, archived);
CREATE INDEX idx_room_notes_forwarded ON room_notes(forwarded_to) WHERE forwarded_to IS NOT NULL;
CREATE INDEX idx_note_shares_type_note ON note_shares(note_type, note_id);
CREATE INDEX idx_note_shares_unread ON note_shares(shared_with, is_read);
CREATE INDEX idx_floor_assignments_date_staff ON floor_assignments(assignment_date, staff_id);
CREATE INDEX idx_floor_assignments_staff ON floor_assignments(staff_id);
CREATE INDEX idx_staff_shifts_date_staff ON staff_shifts(assignment_date, staff_id);
CREATE INDEX idx_staff_shifts_staff ON staff_shifts(staff_id);

-- =============================================
-- UPDATED_AT TRIGGER
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rooms_updated_at
  BEFORE UPDATE ON rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER staff_updated_at
  BEFORE UPDATE ON staff
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER staff_schedules_updated_at
  BEFORE UPDATE ON staff_schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- RPC FUNCTIONS
-- =============================================

-- Reset staff password
CREATE OR REPLACE FUNCTION reset_staff_password(
  p_user_id UUID,
  p_new_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

-- Delete staff auth user
CREATE OR REPLACE FUNCTION delete_staff_auth(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM auth.identities WHERE user_id = p_user_id;
  DELETE FROM auth.sessions WHERE user_id = p_user_id;
  DELETE FROM auth.refresh_tokens WHERE user_id = p_user_id;
  DELETE FROM auth.users WHERE id = p_user_id;
  RETURN FOUND;
END;
$$;

-- Auto-confirm user after admin-created signUp
CREATE OR REPLACE FUNCTION auto_confirm_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, now())
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE floor_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_notes ENABLE ROW LEVEL SECURITY;

-- Rooms
CREATE POLICY "rooms_select" ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY "rooms_insert" ON rooms FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_update" ON rooms FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "rooms_delete" ON rooms FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Room types
CREATE POLICY "room_types_select" ON room_types FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_types_insert" ON room_types FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "room_types_update" ON room_types FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Floors
CREATE POLICY "floors_select" ON floors FOR SELECT TO authenticated USING (true);
CREATE POLICY "floors_insert" ON floors FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);

-- Staff
CREATE POLICY "staff_select" ON staff FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff_select_anon" ON staff FOR SELECT TO anon USING (is_active = true);
CREATE POLICY "staff_insert" ON staff FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'manager')
);
CREATE POLICY "staff_update" ON staff FOR UPDATE TO authenticated USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);
CREATE POLICY "staff_delete" ON staff FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'manager')
);

-- Room notes
CREATE POLICY "room_notes_select" ON room_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_notes_insert" ON room_notes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "room_notes_update" ON room_notes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "room_notes_delete" ON room_notes FOR DELETE TO authenticated USING (true);

-- Chat messages
CREATE POLICY "chat_messages_select" ON chat_messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "chat_messages_insert" ON chat_messages FOR INSERT TO authenticated WITH CHECK (
  sender_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
CREATE POLICY "chat_messages_delete" ON chat_messages FOR DELETE TO authenticated USING (true);

-- Activity log
CREATE POLICY "activity_log_select" ON activity_log FOR SELECT TO authenticated USING (true);
CREATE POLICY "activity_log_insert" ON activity_log FOR INSERT TO authenticated WITH CHECK (true);

-- Personal todos
CREATE POLICY "todos_select" ON personal_todos FOR SELECT TO authenticated
  USING (staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid()));
CREATE POLICY "todos_insert" ON personal_todos FOR INSERT TO authenticated
  WITH CHECK (staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid()));
CREATE POLICY "todos_update" ON personal_todos FOR UPDATE TO authenticated
  USING (staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid()));
CREATE POLICY "todos_delete" ON personal_todos FOR DELETE TO authenticated
  USING (staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid()));

-- Todo list items
CREATE POLICY "todo_list_items_select" ON todo_list_items FOR SELECT TO authenticated
  USING (todo_id IN (
    SELECT id FROM personal_todos
    WHERE staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  ));
CREATE POLICY "todo_list_items_insert" ON todo_list_items FOR INSERT TO authenticated
  WITH CHECK (todo_id IN (
    SELECT id FROM personal_todos
    WHERE staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  ));
CREATE POLICY "todo_list_items_update" ON todo_list_items FOR UPDATE TO authenticated
  USING (todo_id IN (
    SELECT id FROM personal_todos
    WHERE staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  ));
CREATE POLICY "todo_list_items_delete" ON todo_list_items FOR DELETE TO authenticated
  USING (todo_id IN (
    SELECT id FROM personal_todos
    WHERE staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  ));

-- Staff schedules
CREATE POLICY "staff_schedules_select" ON staff_schedules FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff_schedules_insert" ON staff_schedules FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "staff_schedules_update" ON staff_schedules FOR UPDATE TO authenticated USING (true);
CREATE POLICY "staff_schedules_delete" ON staff_schedules FOR DELETE TO authenticated USING (true);

-- AI chat messages
CREATE POLICY "ai_chat_select" ON ai_chat_messages FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ai_chat_insert" ON ai_chat_messages FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "ai_chat_update" ON ai_chat_messages FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ai_chat_delete" ON ai_chat_messages FOR DELETE TO authenticated USING (user_id = auth.uid());

-- Note shares
CREATE POLICY "note_shares_select" ON note_shares FOR SELECT TO authenticated USING (
  shared_with IN (SELECT id FROM staff WHERE user_id = auth.uid())
  OR shared_by IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
CREATE POLICY "note_shares_insert" ON note_shares FOR INSERT TO authenticated WITH CHECK (
  shared_by IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
CREATE POLICY "note_shares_update" ON note_shares FOR UPDATE TO authenticated USING (
  shared_with IN (SELECT id FROM staff WHERE user_id = auth.uid())
  OR shared_by IN (SELECT id FROM staff WHERE user_id = auth.uid())
);
CREATE POLICY "note_shares_delete" ON note_shares FOR DELETE TO authenticated USING (
  shared_by IN (SELECT id FROM staff WHERE user_id = auth.uid())
  OR shared_with IN (SELECT id FROM staff WHERE user_id = auth.uid())
);

-- Floor assignments
CREATE POLICY "floor_assignments_select" ON floor_assignments
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "floor_assignments_insert" ON floor_assignments
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid()
            AND role IN ('manager', 'receptionist'))
  );
CREATE POLICY "floor_assignments_update" ON floor_assignments
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid()
            AND role IN ('manager', 'receptionist'))
  );
CREATE POLICY "floor_assignments_delete" ON floor_assignments
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid()
            AND role IN ('manager', 'receptionist'))
  );

-- Shifts (manager only for writes)
CREATE POLICY "shifts_select" ON shifts
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "shifts_insert" ON shifts
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );
CREATE POLICY "shifts_update" ON shifts
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );
CREATE POLICY "shifts_delete" ON shifts
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );

-- Staff shifts (manager only for writes)
CREATE POLICY "staff_shifts_select" ON staff_shifts
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff_shifts_insert" ON staff_shifts
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );
CREATE POLICY "staff_shifts_update" ON staff_shifts
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );
CREATE POLICY "staff_shifts_delete" ON staff_shifts
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM staff WHERE user_id = auth.uid() AND role = 'manager')
  );

-- Staff notes
CREATE POLICY "staff_notes_manager_all" ON staff_notes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM staff
      WHERE staff.user_id = auth.uid()
        AND staff.role = 'manager'
        AND staff.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM staff
      WHERE staff.user_id = auth.uid()
        AND staff.role = 'manager'
        AND staff.is_active = true
    )
  );

CREATE POLICY "staff_notes_shared_read" ON staff_notes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM note_shares
      WHERE note_shares.note_type = 'staff_note'
        AND note_shares.note_id = staff_notes.id
        AND note_shares.shared_with = (
          SELECT id FROM staff WHERE user_id = auth.uid()
        )
    )
  );

-- =============================================
-- REALTIME
-- =============================================

ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;

-- =============================================
-- GRANTS
-- =============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON room_types TO authenticated;
GRANT SELECT, INSERT ON floors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff TO authenticated;
GRANT SELECT ON staff TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON room_notes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON activity_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON personal_todos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON todo_list_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_schedules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_chat_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON note_shares TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON floor_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON shifts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_shifts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_notes TO authenticated;

-- =============================================
-- SEED DATA
-- =============================================

-- Default room types
INSERT INTO room_types (name, description) VALUES
  ('Single', 'Single bed room'),
  ('Double', 'Double bed room'),
  ('Suite', 'Suite with living area')
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name;

-- Default floors
INSERT INTO floors (number, name) VALUES
  ('P', 'Ground Floor'),
  ('1', 'First Floor'),
  ('2', 'Second Floor'),
  ('3', 'Third Floor')
ON CONFLICT (number) DO NOTHING;

-- Seed 35 rooms across 4 floors
WITH
f_p AS (SELECT id FROM floors WHERE number = 'P'),
f_1 AS (SELECT id FROM floors WHERE number = '1'),
f_2 AS (SELECT id FROM floors WHERE number = '2'),
f_3 AS (SELECT id FROM floors WHERE number = '3'),
t_s AS (SELECT id FROM room_types WHERE name = 'Single'),
t_d AS (SELECT id FROM room_types WHERE name = 'Double'),
t_su AS (SELECT id FROM room_types WHERE name = 'Suite')
INSERT INTO rooms (number, room_type_id, floor_id, status) VALUES
  ('P01', (SELECT id FROM t_s), (SELECT id FROM f_p), 'clean'),
  ('P02', (SELECT id FROM t_s), (SELECT id FROM f_p), 'dirty'),
  ('P03', (SELECT id FROM t_s), (SELECT id FROM f_p), 'clean'),
  ('P04', (SELECT id FROM t_d), (SELECT id FROM f_p), 'dirty'),
  ('P05', (SELECT id FROM t_d), (SELECT id FROM f_p), 'clean'),
  ('P06', (SELECT id FROM t_d), (SELECT id FROM f_p), 'in_progress'),
  ('P07', (SELECT id FROM t_su), (SELECT id FROM f_p), 'clean'),
  ('P08', (SELECT id FROM t_su), (SELECT id FROM f_p), 'dirty'),
  ('101', (SELECT id FROM t_s), (SELECT id FROM f_1), 'clean'),
  ('102', (SELECT id FROM t_s), (SELECT id FROM f_1), 'dirty'),
  ('103', (SELECT id FROM t_s), (SELECT id FROM f_1), 'in_progress'),
  ('104', (SELECT id FROM t_d), (SELECT id FROM f_1), 'clean'),
  ('105', (SELECT id FROM t_d), (SELECT id FROM f_1), 'dirty'),
  ('106', (SELECT id FROM t_d), (SELECT id FROM f_1), 'clean'),
  ('107', (SELECT id FROM t_d), (SELECT id FROM f_1), 'dirty'),
  ('108', (SELECT id FROM t_su), (SELECT id FROM f_1), 'clean'),
  ('109', (SELECT id FROM t_su), (SELECT id FROM f_1), 'dirty'),
  ('201', (SELECT id FROM t_s), (SELECT id FROM f_2), 'dirty'),
  ('202', (SELECT id FROM t_s), (SELECT id FROM f_2), 'clean'),
  ('203', (SELECT id FROM t_s), (SELECT id FROM f_2), 'clean'),
  ('204', (SELECT id FROM t_d), (SELECT id FROM f_2), 'in_progress'),
  ('205', (SELECT id FROM t_d), (SELECT id FROM f_2), 'dirty'),
  ('206', (SELECT id FROM t_d), (SELECT id FROM f_2), 'clean'),
  ('207', (SELECT id FROM t_d), (SELECT id FROM f_2), 'dirty'),
  ('208', (SELECT id FROM t_su), (SELECT id FROM f_2), 'clean'),
  ('209', (SELECT id FROM t_su), (SELECT id FROM f_2), 'dirty'),
  ('301', (SELECT id FROM t_s), (SELECT id FROM f_3), 'clean'),
  ('302', (SELECT id FROM t_s), (SELECT id FROM f_3), 'dirty'),
  ('303', (SELECT id FROM t_s), (SELECT id FROM f_3), 'in_progress'),
  ('304', (SELECT id FROM t_d), (SELECT id FROM f_3), 'clean'),
  ('305', (SELECT id FROM t_d), (SELECT id FROM f_3), 'dirty'),
  ('306', (SELECT id FROM t_d), (SELECT id FROM f_3), 'clean'),
  ('307', (SELECT id FROM t_d), (SELECT id FROM f_3), 'dirty'),
  ('308', (SELECT id FROM t_su), (SELECT id FROM f_3), 'clean'),
  ('309', (SELECT id FROM t_su), (SELECT id FROM f_3), 'dirty')
ON CONFLICT (number) DO NOTHING;

-- Default shifts
INSERT INTO shifts (name, start_time, end_time, color) VALUES
  ('Morning',   '06:00', '14:00', '#FF9800'),
  ('Afternoon', '14:00', '22:00', '#2196F3'),
  ('Night',     '22:00', '06:00', '#9C27B0')
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- ADMIN SETUP (run after migration)
-- =============================================
-- Step 1: In Supabase Dashboard -> Authentication -> Users -> Add User
--         Email: manager@hotel.local
--         Password: th131S13a330rD
--         Auto Confirm: ✅
--         Copy the new user's UUID.
--
-- Step 2: Run this with the UUID pasted in:
--         INSERT INTO staff (id, user_id, name, account_name, role, login_email, is_active)
--         VALUES (gen_random_uuid(), '<PASTE_USER_UUID>', 'Manager', 'manager', 'manager', 'manager@hotel.local', true);
