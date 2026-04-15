-- Player responses and scores per round
create table public.scores (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  round_id uuid not null references public.session_rounds(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  chosen_option char(1) not null check (chosen_option in ('a', 'b')),
  response_time_ms int not null check (response_time_ms >= 0),
  points_earned int not null default 0,
  answered_at timestamptz not null default now(),
  unique (round_id, user_id)
);

comment on table public.scores is 'Player answers and points per round';

create index idx_scores_session on public.scores (session_id);
create index idx_scores_user on public.scores (user_id);
create index idx_scores_round on public.scores (round_id);

-- RLS for scores
alter table public.scores enable row level security;

create policy "Participants can view session scores"
  on public.scores for select
  using (
    exists (
      select 1 from public.session_participants sp
      where sp.session_id = scores.session_id
        and sp.user_id = auth.uid()
    )
  );

create policy "Users can insert own scores"
  on public.scores for insert
  with check (auth.uid() = user_id);

-- Aggregate function for leaderboard
create or replace function public.get_leaderboard(limit_count int default 50)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  total_score bigint,
  games_played int,
  games_won int
) as $$
  select
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.total_score,
    u.games_played,
    u.games_won
  from public.users u
  order by u.total_score desc
  limit limit_count;
$$ language sql stable security definer;

-- Function to update user stats after a game completes
create or replace function public.update_user_stats_on_game_complete()
returns trigger as $$
declare
  v_winner_id uuid;
  v_participant record;
begin
  if new.status = 'completed' and old.status = 'active' then
    -- Find the winner (highest total points in this session)
    select user_id into v_winner_id
    from public.scores
    where session_id = new.id
    group by user_id
    order by sum(points_earned) desc
    limit 1;

    -- Update stats for all participants
    for v_participant in
      select sp.user_id, coalesce(sum(s.points_earned), 0) as session_score
      from public.session_participants sp
      left join public.scores s on s.session_id = new.id and s.user_id = sp.user_id
      where sp.session_id = new.id
      group by sp.user_id
    loop
      update public.users set
        games_played = games_played + 1,
        games_won = games_won + case when v_participant.user_id = v_winner_id then 1 else 0 end,
        total_score = total_score + v_participant.session_score
      where id = v_participant.user_id;
    end loop;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_session_completed
  after update on public.sessions
  for each row
  when (new.status = 'completed' and old.status = 'active')
  execute function public.update_user_stats_on_game_complete();
