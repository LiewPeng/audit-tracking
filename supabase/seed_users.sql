-- Initial team accounts (run once, as the postgres role, e.g. in the Supabase SQL editor).
-- Everyone starts with the password "password" — ask each person to change it under Account.
select private.create_app_user('priya',  'password', 'Priya',  'admin');
select private.create_app_user('dan',    'password', 'Dan',    'auditor');
select private.create_app_user('marcus', 'password', 'Marcus', 'auditor');
