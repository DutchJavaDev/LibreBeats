-- Listener user, confirmed from the start.
-- From https://github.com/orgs/supabase/discussions/5043#discussioncomment-6191165
-- plus the provider_id fix mentioned further down. DO block instead of their
-- create_user() helper, a function in public would end up as an rpc endpoint.
DO $$
DECLARE
  user_id uuid;
BEGIN
  IF EXISTS (SELECT FROM auth.users WHERE email = 'listner@librebeats.com') THEN
    RETURN;
  END IF;

  user_id := gen_random_uuid();

  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password,
     email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
     created_at, updated_at,
     confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated',
     'authenticated', 'listner@librebeats.com',
     extensions.crypt('T~r&-7(TvDs{9T1ha:k7', extensions.gen_salt('bf')),
     now(), '{"provider":"email","providers":["email"]}', '{}',
     now(), now(),
     '', '', '', '');

  INSERT INTO auth.identities
    (id, provider_id, user_id, identity_data, provider,
     last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id::text, user_id,
     format('{"sub":"%s","email":"%s"}', user_id::text, 'listner@librebeats.com')::jsonb,
     'email', now(), now(), now());
END $$;
