-- Challenge categories
create type public.challenge_category as enum (
  'lifestyle', 'food', 'travel', 'entertainment',
  'relationships', 'career', 'hypothetical', 'silly'
);

-- Would You Rather challenges
create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  option_a text not null,
  option_b text not null,
  category public.challenge_category not null default 'hypothetical',
  difficulty int not null default 1 check (difficulty between 1 and 5),
  is_active boolean not null default true,
  times_used int not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.challenges is 'Would You Rather question prompts';

create index idx_challenges_category on public.challenges (category) where is_active = true;
create index idx_challenges_active on public.challenges (is_active, difficulty);

-- Session rounds linking sessions to challenges
create table public.session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id),
  round_number int not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  unique (session_id, round_number)
);

comment on table public.session_rounds is 'Individual rounds within a game session';

create index idx_session_rounds_session on public.session_rounds (session_id, round_number);

-- RLS for challenges
alter table public.challenges enable row level security;

create policy "Anyone can view active challenges"
  on public.challenges for select
  using (is_active = true);

-- RLS for session_rounds
alter table public.session_rounds enable row level security;

create policy "Anyone can view session rounds"
  on public.session_rounds for select
  using (true);

create policy "Host can create rounds"
  on public.session_rounds for insert
  with check (
    exists (
      select 1 from public.sessions
      where id = session_id and host_id = auth.uid()
    )
  );
