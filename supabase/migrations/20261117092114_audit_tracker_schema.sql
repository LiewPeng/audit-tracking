-- ============ Private helper schema (not exposed through the API) ============
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ============ Profiles (one per auth user) ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._-]{2,32}$'),
  full_name text not null default '',
  role text not null default 'auditor' check (role in ('admin','auditor')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid());
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
revoke all on function public.is_member() from public, anon;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_member() to authenticated;
grant execute on function public.is_admin() to authenticated;

create policy "Members can read profiles" on public.profiles
  for select to authenticated using ((select public.is_member()));
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke all on public.profiles from anon;
revoke insert, update, delete on public.profiles from authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

-- Only users created through the app's admin function get a profile (and therefore data access).
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_app_meta_data->>'managed','') = 'true' then
    insert into public.profiles (id, username, full_name, role)
    values (new.id,
            lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1))),
            coalesce(new.raw_user_meta_data->>'full_name',''),
            case when new.raw_app_meta_data->>'app_role' = 'admin' then 'admin' else 'auditor' end);
  end if;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- ============ Shared touch trigger ============
create or replace function private.touch_row() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

-- ============ Engagement settings (single row) ============
create table public.engagement (
  id smallint primary key default 1 check (id = 1),
  entity text not null default '',
  period_end date,
  materiality numeric not null default 50000,
  pm_pct numeric not null default 75,
  ct_pct numeric not null default 5,
  fluct_pct numeric not null default 20,
  cutoff_days integer not null default 5,
  holidays text not null default '',
  preparer text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
insert into public.engagement (id) values (1);
create index engagement_updated_by_idx on public.engagement(updated_by);
create trigger engagement_touch before update on public.engagement
  for each row execute function private.touch_row();
alter table public.engagement enable row level security;
create policy "Members can read engagement" on public.engagement
  for select to authenticated using ((select public.is_member()));
create policy "Members can update engagement" on public.engagement
  for update to authenticated using ((select public.is_member())) with check ((select public.is_member()));
revoke all on public.engagement from anon;
revoke insert, delete, truncate on public.engagement from authenticated;

-- ============ Workbooks ============
create table public.workbooks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  size bigint not null default 0,
  sample boolean not null default false,
  sheets jsonb not null default '[]'::jsonb,
  summary jsonb,
  last_run timestamptz,
  uploaded_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
create index workbooks_uploaded_by_idx on public.workbooks(uploaded_by);
create index workbooks_updated_by_idx on public.workbooks(updated_by);
create trigger workbooks_touch before insert or update on public.workbooks
  for each row execute function private.touch_row();
alter table public.workbooks enable row level security;
create policy "Members can read workbooks" on public.workbooks
  for select to authenticated using ((select public.is_member()));
create policy "Members can add workbooks" on public.workbooks
  for insert to authenticated with check ((select public.is_member()));
create policy "Members can update workbooks" on public.workbooks
  for update to authenticated using ((select public.is_member())) with check ((select public.is_member()));
create policy "Members can delete workbooks" on public.workbooks
  for delete to authenticated using ((select public.is_member()));
revoke all on public.workbooks from anon;

-- ============ Issues ============
create sequence public.issue_code_seq;
create table public.issues (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default ('AT-' || lpad(nextval('public.issue_code_seq')::text, 3, '0')),
  fp text not null,
  workbook_id uuid references public.workbooks(id) on delete set null,
  file_name text not null default '',
  sheet text not null default '',
  cells jsonb not null default '[]'::jsonb,
  title text not null,
  detail text not null default '',
  amount numeric,
  category text not null,
  assertion text not null default '',
  risk text not null check (risk in ('High','Medium','Low')),
  prio_override text check (prio_override in ('P1','P2','P3')),
  risk_edited boolean not null default false,
  cat_edited boolean not null default false,
  fraud boolean not null default false,
  movement boolean not null default false,
  stale boolean not null default false,
  refs text[] not null default '{}',
  test text,
  source text not null default 'auto' check (source in ('auto','manual')),
  status text not null default 'Open' check (status in ('Open','In review','Awaiting client','Resolved','Not an issue')),
  owner text not null default '',
  notes text not null default '',
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
create index issues_workbook_id_idx on public.issues(workbook_id);
create index issues_created_by_idx on public.issues(created_by);
create index issues_updated_by_idx on public.issues(updated_by);
create trigger issues_touch before insert or update on public.issues
  for each row execute function private.touch_row();
alter table public.issues enable row level security;
create policy "Members can read issues" on public.issues
  for select to authenticated using ((select public.is_member()));
create policy "Members can add issues" on public.issues
  for insert to authenticated with check ((select public.is_member()));
create policy "Members can update issues" on public.issues
  for update to authenticated using ((select public.is_member())) with check ((select public.is_member()));
create policy "Members can delete issues" on public.issues
  for delete to authenticated using ((select public.is_member()));
revoke all on public.issues from anon;
revoke all on sequence public.issue_code_seq from anon;
grant usage on sequence public.issue_code_seq to authenticated;

-- ============ Realtime ============
alter publication supabase_realtime add table public.issues, public.workbooks, public.engagement, public.profiles;

-- ============ User management ============
create or replace function private.create_app_user(p_username text, p_password text, p_full_name text, p_role text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := gen_random_uuid();
  v_username text := lower(trim(p_username));
  v_email text := lower(trim(p_username)) || '@audit-tracker.local';
begin
  if v_username !~ '^[a-z0-9._-]{2,32}$' then
    raise exception 'Username must be 2–32 characters: lowercase letters, numbers, dot, dash or underscore' using errcode = '22023';
  end if;
  if length(coalesce(p_password,'')) < 8 then
    raise exception 'Password must be at least 8 characters' using errcode = '22023';
  end if;
  if p_role not in ('admin','auditor') then
    raise exception 'Role must be admin or auditor' using errcode = '22023';
  end if;
  if exists (select 1 from auth.users where email = v_email) or exists (select 1 from public.profiles where username = v_username) then
    raise exception 'Username % is already taken', v_username using errcode = '23505';
  end if;

  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token,
    is_sso_user, is_anonymous)
  values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'managed',true,'app_role',p_role),
    jsonb_build_object('username',v_username,'full_name',coalesce(p_full_name,'')),
    now(), now(), '', '', '', '', '', '', '', '', false, false);

  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
    'email', null, now(), now());

  return v_id;
end $$;
revoke all on function private.create_app_user(text,text,text,text) from public, anon, authenticated;

create or replace function public.admin_create_user(p_username text, p_password text, p_full_name text default '', p_role text default 'auditor')
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can add users' using errcode = '42501';
  end if;
  return private.create_app_user(p_username, p_password, p_full_name, p_role);
end $$;

create or replace function public.admin_list_users()
returns table (id uuid, username text, full_name text, role text, created_at timestamptz, last_sign_in_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can list users' using errcode = '42501';
  end if;
  return query
    select p.id, p.username, p.full_name, p.role, p.created_at, u.last_sign_in_at
    from public.profiles p join auth.users u on u.id = p.id
    order by p.username;
end $$;

create or replace function public.admin_set_password(p_user uuid, p_password text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can reset passwords' using errcode = '42501';
  end if;
  if length(coalesce(p_password,'')) < 8 then
    raise exception 'Password must be at least 8 characters' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  update auth.users set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')), updated_at = now()
  where id = p_user;
end $$;

create or replace function public.admin_update_user(p_user uuid, p_full_name text, p_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can edit users' using errcode = '42501';
  end if;
  if p_role not in ('admin','auditor') then
    raise exception 'Role must be admin or auditor' using errcode = '22023';
  end if;
  if p_role <> 'admin'
     and exists (select 1 from public.profiles where id = p_user and role = 'admin')
     and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'At least one administrator is required' using errcode = '22023';
  end if;
  update public.profiles set full_name = coalesce(p_full_name,''), role = p_role where id = p_user;
  update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('app_role', p_role), updated_at = now()
  where id = p_user;
end $$;

create or replace function public.admin_delete_user(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can remove users' using errcode = '42501';
  end if;
  if p_user = auth.uid() then
    raise exception 'You cannot remove your own account' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  delete from auth.users where id = p_user;
end $$;

revoke all on function public.admin_create_user(text,text,text,text) from public, anon;
revoke all on function public.admin_list_users() from public, anon;
revoke all on function public.admin_set_password(uuid,text) from public, anon;
revoke all on function public.admin_update_user(uuid,text,text) from public, anon;
revoke all on function public.admin_delete_user(uuid) from public, anon;
grant execute on function public.admin_create_user(text,text,text,text) to authenticated;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_set_password(uuid,text) to authenticated;
grant execute on function public.admin_update_user(uuid,text,text) to authenticated;
grant execute on function public.admin_delete_user(uuid) to authenticated;
