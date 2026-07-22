-- Housekeeping App - Consolidated Schema
-- Single migration representing the complete database state

-- =============================================
-- ENUMS
-- =============================================

CREATE TYPE room_status AS ENUM ('dirty', 'in_progress', 'clean');
CREATE TYPE staff_role AS ENUM ('cleaner', 'receptionist');

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

CREATE TABLE room_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE(room_id, staff_id, assigned_at)
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

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_floor ON rooms(floor_id);
CREATE INDEX idx_room_assignments_room ON room_assignments(room_id);
CREATE INDEX idx_room_assignments_staff ON room_assignments(staff_id);
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

-- Create staff auth user (robust, dynamic column matching for any Supabase version)
DROP FUNCTION IF EXISTS create_staff_auth(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION create_staff_auth(
  p_staff_id UUID,
  p_email TEXT,
  p_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_result JSON;
  v_cols TEXT := '';
  v_vals TEXT := '';
  v_first BOOLEAN := true;
  v_col_name TEXT;
  v_default_val TEXT;
BEGIN
  v_user_id := gen_random_uuid();

  FOR v_col_name IN
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'auth' AND table_name = 'users'
    ORDER BY ordinal_position
  LOOP
    v_default_val := NULL;

    CASE v_col_name
      WHEN 'id' THEN v_default_val := quote_literal(v_user_id);
      WHEN 'instance_id' THEN v_default_val := quote_literal('00000000-0000-0000-0000-000000000000');
      WHEN 'aud' THEN v_default_val := quote_literal('authenticated');
      WHEN 'role' THEN v_default_val := quote_literal('authenticated');
      WHEN 'email' THEN v_default_val := quote_literal(p_email);
      WHEN 'encrypted_password' THEN v_default_val := quote_literal(crypt(p_password, gen_salt('bf')));
      WHEN 'email_confirmed_at' THEN v_default_val := quote_literal(now());
      WHEN 'confirmation_token' THEN v_default_val := quote_literal('');
      WHEN 'recovery_token' THEN v_default_val := quote_literal('');
      WHEN 'email_change' THEN v_default_val := quote_literal('');
      WHEN 'email_change_token_current' THEN v_default_val := quote_literal('');
      WHEN 'email_change_token_new' THEN v_default_val := quote_literal('');
      WHEN 'phone_change' THEN v_default_val := quote_literal('');
      WHEN 'phone_change_token' THEN v_default_val := quote_literal('');
      WHEN 'reauthentication_token' THEN v_default_val := quote_literal('');
      WHEN 'is_super_admin' THEN v_default_val := 'false';
      WHEN 'raw_app_meta_data' THEN v_default_val := quote_literal('{"provider":"email","providers":["email"]}'::jsonb);
      WHEN 'raw_user_meta_data' THEN v_default_val := quote_literal('{}'::jsonb);
      WHEN 'created_at' THEN v_default_val := quote_literal(now());
      WHEN 'updated_at' THEN v_default_val := quote_literal(now());
      WHEN 'last_sign_in_at' THEN v_default_val := quote_literal(now());
      WHEN 'phone' THEN v_default_val := 'NULL';
      WHEN 'phone_confirmed_at' THEN v_default_val := 'NULL';
      WHEN 'confirmation_sent_at' THEN v_default_val := quote_literal(now());
      WHEN 'recovery_sent_at' THEN v_default_val := 'NULL';
      WHEN 'email_change_sent_at' THEN v_default_val := 'NULL';
      WHEN 'phone_change_sent_at' THEN v_default_val := 'NULL';
      WHEN 'is_sso_user' THEN v_default_val := 'false';
      ELSE v_default_val := NULL;
    END CASE;

    IF v_default_val IS NOT NULL THEN
      IF NOT v_first THEN
        v_cols := v_cols || ', ';
        v_vals := v_vals || ', ';
      END IF;
      v_cols := v_cols || quote_ident(v_col_name);
      v_vals := v_vals || v_default_val;
      v_first := FALSE;
    END IF;
  END LOOP;

  EXECUTE format('INSERT INTO auth.users (%s) VALUES (%s)', v_cols, v_vals);

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id
  ) VALUES (
    v_user_id, v_user_id,
    json_build_object('sub', v_user_id, 'email', p_email),
    'email', p_email
  );

  UPDATE staff SET user_id = v_user_id WHERE id = p_staff_id;

  v_result := json_build_object(
    'user_id', v_user_id,
    'staff_id', p_staff_id,
    'email', p_email
  );
  RETURN v_result;
END;
$$;

-- Reset staff password
DROP FUNCTION IF EXISTS reset_staff_password(UUID, TEXT);

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

-- Delete staff auth user (TEXT param for PostgREST compatibility)
DROP FUNCTION IF EXISTS delete_staff_auth(UUID);
DROP FUNCTION IF EXISTS delete_staff_auth(TEXT);

CREATE OR REPLACE FUNCTION delete_staff_auth(p_user_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := p_user_id::uuid;
BEGIN
  DELETE FROM auth.identities WHERE user_id = v_user_id;
  DELETE FROM auth.sessions WHERE user_id = v_user_id;
  DELETE FROM auth.refresh_tokens WHERE user_id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;
  RETURN FOUND;
END;
$$;

-- Auto-confirm user after admin-created signUp
DROP FUNCTION IF EXISTS auto_confirm_user(UUID);

CREATE OR REPLACE FUNCTION auto_confirm_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      confirmed_at = COALESCE(confirmed_at, now())
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
ALTER TABLE room_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_messages ENABLE ROW LEVEL SECURITY;

-- Rooms
CREATE POLICY "rooms_select" ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY "rooms_insert" ON rooms FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);
CREATE POLICY "rooms_update" ON rooms FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);
CREATE POLICY "rooms_delete" ON rooms FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);

-- Room types
CREATE POLICY "room_types_select" ON room_types FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_types_insert" ON room_types FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);
CREATE POLICY "room_types_update" ON room_types FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);

-- Floors
CREATE POLICY "floors_select" ON floors FOR SELECT TO authenticated USING (true);
CREATE POLICY "floors_insert" ON floors FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);

-- Staff
CREATE POLICY "staff_select" ON staff FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff_select_anon" ON staff FOR SELECT TO anon USING (is_active = true);
CREATE POLICY "staff_insert" ON staff FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);
CREATE POLICY "staff_update" ON staff FOR UPDATE TO authenticated USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'receptionist')
);
CREATE POLICY "staff_delete" ON staff FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff s WHERE s.user_id = auth.uid() AND s.role = 'receptionist')
);

-- Room assignments
CREATE POLICY "room_assignments_select" ON room_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_assignments_insert" ON room_assignments FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
);
CREATE POLICY "room_assignments_update" ON room_assignments FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM staff WHERE staff.user_id = auth.uid() AND staff.role = 'receptionist')
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
CREATE POLICY "staff_schedules_insert" ON staff_schedules FOR INSERT TO authenticated USING (true);
CREATE POLICY "staff_schedules_update" ON staff_schedules FOR UPDATE TO authenticated USING (true);
CREATE POLICY "staff_schedules_delete" ON staff_schedules FOR DELETE TO authenticated USING (true);

-- AI chat messages
CREATE POLICY "ai_chat_select" ON ai_chat_messages FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ai_chat_insert" ON ai_chat_messages FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "ai_chat_update" ON ai_chat_messages FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ai_chat_delete" ON ai_chat_messages FOR DELETE TO authenticated USING (user_id = auth.uid());

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
GRANT SELECT, INSERT, UPDATE, DELETE ON room_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON room_notes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON activity_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON personal_todos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON todo_list_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_schedules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_chat_messages TO authenticated;

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

-- Seed admin account (admin@hotel.local / admin123)
DO $block$
DECLARE
  v_user_id UUID;
  v_staff_id UUID;
  v_instance_id UUID;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@hotel.local') THEN
    RETURN;
  END IF;

  SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;

  v_user_id := gen_random_uuid();
  v_staff_id := gen_random_uuid();

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at,
    confirmation_token, recovery_token,
    email_change, email_change_token_current, email_change_token_new,
    phone_change, phone_change_token, reauthentication_token,
    is_sso_user
  ) VALUES (
    COALESCE(v_instance_id, '00000000-0000-0000-0000-000000000000'),
    v_user_id, 'authenticated', 'authenticated',
    'admin@hotel.local', crypt('admin123', gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    false, NOW(), NOW(),
    '', '', '', '', '', '', '', '', false
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id
  ) VALUES (
    v_user_id, v_user_id,
    json_build_object('sub', v_user_id, 'email', 'admin@hotel.local'),
    'email', 'admin@hotel.local'
  );

  INSERT INTO staff (id, user_id, name, account_name, role, phone, login_email, is_active)
  VALUES (v_staff_id, v_user_id, 'Admin', 'admin', 'receptionist', NULL, 'admin@hotel.local', true);

END;
$block$;
