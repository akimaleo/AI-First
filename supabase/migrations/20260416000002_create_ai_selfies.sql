-- AI selfie transform jobs (Capture the Moment)
create type public.ai_selfie_status as enum (
  'pending', 'processing', 'succeeded', 'failed', 'cancelled'
);

create table public.ai_selfies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  session_id uuid references public.sessions(id) on delete set null,
  round_id uuid references public.session_rounds(id) on delete set null,
  prompt_key text not null,
  prompt_text text,
  model text not null,
  input_path text not null,
  output_url text,
  provider_job_id text,
  status public.ai_selfie_status not null default 'pending',
  error_message text,
  latency_ms int,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

comment on table public.ai_selfies is
  'AI Capture the Moment: selfie transform jobs and their outputs';

create index idx_ai_selfies_user on public.ai_selfies (user_id, created_at desc);
create index idx_ai_selfies_session on public.ai_selfies (session_id)
  where session_id is not null;
create index idx_ai_selfies_status on public.ai_selfies (status)
  where status in ('pending', 'processing');

alter table public.ai_selfies enable row level security;

create policy "Users can view their own selfies"
  on public.ai_selfies for select
  using (auth.uid() = user_id);

create policy "Users can view session selfies for sessions they're in"
  on public.ai_selfies for select
  using (
    session_id is not null
    and exists (
      select 1 from public.session_participants
      where session_id = public.ai_selfies.session_id
        and user_id = auth.uid()
    )
  );

-- Only the service role (edge function) inserts/updates.
-- Clients trigger the flow through the selfie-transform function.

-- Storage bucket for raw captures and generated outputs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'selfies',
  'selfies',
  false,
  10 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "Users can upload their own selfies"
  on storage.objects for insert
  with check (
    bucket_id = 'selfies'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can read their own selfies"
  on storage.objects for select
  using (
    bucket_id = 'selfies'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
