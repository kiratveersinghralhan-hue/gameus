-- Phase 5: bounded game-room lifecycle. Apply AFTER 202610200001_game.sql.
-- Run SELECT public.bu_cleanup_expired(); periodically in SQL Editor, or via
-- a trusted pg_cron schedule when the extension is available on your plan.
-- Expire entire rooms after 14 days of no activity, not based on personal answers.
create or replace function public.bu_cleanup_expired()
returns table(rooms_deleted bigint, events_deleted bigint)
language plpgsql security definer set search_path = '' as $$
declare nrooms bigint := 0; nevents bigint := 0;
begin
  -- Remove old notifications for otherwise active rooms. Never depend on
  -- notifications as a durable event log; clients refresh authoritative state.
  delete from public.bu_events where created_at < now() - interval '2 days';
  get diagnostics nevents = row_count;
  delete from public.bu_rooms where updated_at < now() - interval '14 days';
  get diagnostics nrooms = row_count;
  return query select nrooms, nevents;
end $$;
revoke all on function public.bu_cleanup_expired() from public, anon, authenticated;
grant execute on function public.bu_cleanup_expired() to service_role;
-- Optional server-side scheduled cleanup (only if pg_cron is installed):
-- select cron.schedule('bu-cleanup', '15 3 * * *', $$select * from public.bu_cleanup_expired()$$);
