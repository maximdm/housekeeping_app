-- =====================================================
-- MANAGER ACCOUNT CREATION GUIDE
-- Run these commands in Supabase SQL Editor
-- =====================================================

-- STEP 1: Disable the manager insert trigger
ALTER TABLE staff DISABLE TRIGGER block_manager_insert;

-- STEP 2: Create the auth user (Supabase auth)
-- Replace 'manager@example.com' and 'SecurePassword123!' with actual values
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'manager@example.com',  -- CHANGE THIS
  crypt('SecurePassword123!', gen_salt('bf')),  -- CHANGE THIS
  now(),
  now(),
  now(),
  '',
  ''
)
RETURNING id;

-- STEP 3: Copy the user ID from Step 2 result, then insert staff row
-- Replace 'YOUR_USER_ID_HERE' with the actual UUID from Step 2
INSERT INTO staff (name, account_name, role, user_id, is_active)
VALUES (
  'Admin Name',        -- CHANGE THIS: Display name
  'admin',             -- CHANGE THIS: Login username
  'manager',
  'YOUR_USER_ID_HERE', -- CHANGE THIS: UUID from Step 2
  true
);

-- STEP 4: Re-enable the trigger
ALTER TABLE staff ENABLE TRIGGER block_manager_insert;

-- =====================================================
-- QUICK VERSION (single query, no trigger disable needed)
-- Use this if you prefer a simpler approach:
-- =====================================================
-- 
-- INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
-- VALUES ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'manager@example.com', crypt('YourPassword123!', gen_salt('bf')), now(), now(), now())
-- RETURNING id;
-- 
-- Then use the returned ID:
-- INSERT INTO staff (name, account_name, role, user_id, is_active) VALUES ('Admin', 'admin', 'manager', 'PASTE_ID_HERE', true);
