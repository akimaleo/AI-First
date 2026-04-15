-- Game session types
create type public.session_status as enum ('waiting', 'active', 'completed', 'cancelled');
create type public.session_mode as enum ('solo', 'versus', 'group');

-- Game sessions
create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.users(id) on delete cascade,
  mode public.session_mode not null default 'versus',
  status public.session_status not null default 'waiting',
  max_players int not null default 2 check (max_players between 1 and 10),
  current_round int not null default 0,
  total_rounds int not null default 10,
  invite_code text unique,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.sessions is 'Game sessions for Would You Rather challenges';

-- Indexes
create index idx_sessions_host on public.sessions (host_id);
create index idx_sessions_status on public.sessions (status) where status in ('waiting', 'active');
create index idx_sessions_invite_code on public.sessions (invite_code) where invite_code is not null;

-- Updated_at trigger
create trigger on_sessions_updated
  before update on public.sessions
  for each row execute function public.handle_updated_at();

-- Session participants (join table)
create table public.session_participants (
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  is_ready boolean not null default false,
  primary key (session_id, user_id)
);

comment on table public.session_participants is 'Players who have joined a game session';

create index idx_session_participants_user on public.session_participants (user_id);

-- RLS for sessions
alter table public.sessions enable row level security;

create policy "Anyone can view active sessions"
  on public.sessions for select
  using (true);

create policy "Authenticated users can create sessions"
  on public.sessions for insert
  with check (auth.uid() = host_id);

create policy "Host can update own session"
  on public.sessions for update
  using (auth.uid() = host_id);

create policy "Host can delete own waiting session"
  on public.sessions for delete
  using (auth.uid() = host_id and status = 'waiting');

-- RLS for session_participants
alter table public.session_participants enable row level security;

create policy "Anyone can view participants"
  on public.session_participants for select
  using (true);

create policy "Authenticated users can join sessions"
  on public.session_participants for insert
  with check (auth.uid() = user_id);

create policy "Users can update own participation"
  on public.session_participants for update
  using (auth.uid() = user_id);

create policy "Users can leave sessions"
  on public.session_participants for delete
  using (auth.uid() = user_id);
