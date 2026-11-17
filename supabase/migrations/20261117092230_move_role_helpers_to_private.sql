alter function public.is_member() set schema private;
alter function public.is_admin() set schema private;
grant usage on schema private to authenticated;
revoke all on function private.is_member() from public, anon;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_member() to authenticated;
grant execute on function private.is_admin() to authenticated;
revoke all on function private.touch_row() from public, anon, authenticated;
revoke all on function private.handle_new_user() from public, anon, authenticated;

do $$
declare f record; def text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    def := pg_get_functiondef(f.oid);
    def := replace(def, 'public.is_admin()', 'private.is_admin()');
    execute def;
  end loop;
end $$;
