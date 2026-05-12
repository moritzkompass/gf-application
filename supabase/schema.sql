-- GF Application — Schema
-- Im selben Supabase-Projekt wie weblift (lwjyhsdlqpohnttxoacr), aber gf_-Prefix
-- und separater Storage-Bucket — keine Berührung mit business leads.

-- ============================================================
-- Table: gf_applications
-- ============================================================
create table if not exists public.gf_applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  status text not null default 'neu',                  -- neu | gelesen | passt | passt_nicht
  notes text,

  -- Kontakt
  name text not null,
  kontakt text not null,                                -- @handle, Email oder Nummer

  -- Quiz-Antworten
  typ text,                                             -- was sucht sie
  adjektive text[],                                     -- multi
  sonntag text,
  rapid_lieblingswort text,
  rapid_ohrwurm text,
  rapid_bag text,
  greenflags text,
  interesse text,
  date_wahl text,
  date_text text,                                       -- nur wenn "Überrasch mich"
  comms text,
  rueckfrage text,

  -- Voice / Video / Text Message
  message_type text,                                    -- voice | video | text
  message_text text,
  message_url text,
  message_duration_sec integer,

  -- Meta
  user_agent text,
  referrer_url text
);

create index if not exists gf_applications_created_at_idx
  on public.gf_applications(created_at desc);

alter table public.gf_applications enable row level security;

-- Authenticated users (Moritz im Admin) dürfen alles
drop policy if exists gf_apps_auth_select on public.gf_applications;
create policy gf_apps_auth_select on public.gf_applications
  for select to authenticated using (true);
drop policy if exists gf_apps_auth_update on public.gf_applications;
create policy gf_apps_auth_update on public.gf_applications
  for update to authenticated using (true) with check (true);
drop policy if exists gf_apps_auth_delete on public.gf_applications;
create policy gf_apps_auth_delete on public.gf_applications
  for delete to authenticated using (true);

-- ============================================================
-- RPC: submit_gf_application
-- Security definer, bypassed RLS (gleicher Workaround wie submit_lead bei weblift)
-- ============================================================
create or replace function public.submit_gf_application(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  insert into public.gf_applications (
    name, kontakt,
    typ, adjektive, sonntag,
    rapid_lieblingswort, rapid_ohrwurm, rapid_bag,
    greenflags, interesse,
    date_wahl, date_text,
    comms, rueckfrage,
    message_type, message_text, message_url, message_duration_sec,
    user_agent, referrer_url
  ) values (
    payload->>'name',
    payload->>'kontakt',
    payload->>'typ',
    case when payload ? 'adjektive'
         then array(select jsonb_array_elements_text(payload->'adjektive'))
         else null end,
    payload->>'sonntag',
    payload->>'rapid_lieblingswort',
    payload->>'rapid_ohrwurm',
    payload->>'rapid_bag',
    payload->>'greenflags',
    payload->>'interesse',
    payload->>'date_wahl',
    payload->>'date_text',
    payload->>'comms',
    payload->>'rueckfrage',
    payload->>'message_type',
    payload->>'message_text',
    payload->>'message_url',
    nullif(payload->>'message_duration_sec','')::integer,
    payload->>'user_agent',
    payload->>'referrer_url'
  )
  returning id into new_id;
  return new_id;
end;
$$;

grant execute on function public.submit_gf_application(jsonb) to anon;
grant execute on function public.submit_gf_application(jsonb) to authenticated;

-- ============================================================
-- Storage: gf-voice-messages bucket
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gf-voice-messages', 'gf-voice-messages', true, 52428800, null)
on conflict (id) do update set public = true, file_size_limit = 52428800, allowed_mime_types = null;

-- Public read
drop policy if exists "gf voice public read" on storage.objects;
create policy "gf voice public read" on storage.objects
  for select using (bucket_id = 'gf-voice-messages');

-- Anon upload
drop policy if exists "gf voice anon insert" on storage.objects;
create policy "gf voice anon insert" on storage.objects
  for insert to anon with check (bucket_id = 'gf-voice-messages');
