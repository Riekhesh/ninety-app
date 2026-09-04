-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — migration 003: the meal-photos bucket and its policies.
--
-- Separate from 002 on purpose. `storage.objects` is owned by
-- supabase_storage_admin rather than by the role that runs migrations, so
-- creating policies on it is the one step here that can fail for reasons of
-- ownership rather than of SQL.
--
-- Each migration runs in a single transaction. Folded into 002, a permissions
-- failure on this section would roll back every table policy with it and leave
-- ten tables with RLS on and nothing granted — safe, but completely broken, and
-- a confusing thing to diagnose. On its own, a failure here costs only the photo
-- bucket, which nothing needs until P1-F.
--
-- If it does fail, the same four policies can be made in the dashboard under
-- Storage → meal-photos → Policies. See supabase/README.md.
-- ═══════════════════════════════════════════════════════════════════════════


-- Private bucket, signed URLs with a short expiry, never public. A meal photo
-- is Article 9 health data; a public bucket URL is a permanent, unauthenticated
-- link to it.
--
-- Objects are keyed <user-uuid>/<filename>, so the first path segment is the
-- owner and every policy checks it.

insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

create policy meal_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy meal_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy meal_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Deletion has to work for the Article 9 right to erasure: account deletion
-- must remove the Storage objects too, not only the rows that point at them.
create policy meal_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
