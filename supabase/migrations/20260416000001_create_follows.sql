-- Social graph: follow/friend relationships between users
create table public.follows (
  follower_id uuid not null references public.users(id) on delete cascade,
  followee_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

comment on table public.follows is 'Directed social graph: follower_id follows followee_id';

create index idx_follows_follower on public.follows (follower_id);
create index idx_follows_followee on public.follows (followee_id);

-- RLS
alter table public.follows enable row level security;

create policy "Anyone can read follows"
  on public.follows for select
  using (true);

create policy "Users can follow as themselves"
  on public.follows for insert
  with check (auth.uid() = follower_id);

create policy "Users can unfollow their own edges"
  on public.follows for delete
  using (auth.uid() = follower_id);

-- Friends leaderboard: top scores across users the caller follows (plus caller)
create or replace function public.get_friends_leaderboard(limit_count int default 50)
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
  where u.id = auth.uid()
     or u.id in (
       select followee_id from public.follows where follower_id = auth.uid()
     )
  order by u.total_score desc
  limit limit_count;
$$ language sql stable security definer;

-- User profile with follow counts + whether caller follows them
create or replace function public.get_user_profile(target_user_id uuid)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  level int,
  total_score bigint,
  games_played int,
  games_won int,
  followers_count bigint,
  following_count bigint,
  is_following boolean
) as $$
  select
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.bio,
    u.level,
    u.total_score,
    u.games_played,
    u.games_won,
    (select count(*) from public.follows f where f.followee_id = u.id),
    (select count(*) from public.follows f where f.follower_id = u.id),
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.followee_id = u.id
    )
  from public.users u
  where u.id = target_user_id;
$$ language sql stable security definer;

-- Challenge history for a user: completed sessions they participated in
-- plus their total points and rank within the session
create or replace function public.get_user_history(
  target_user_id uuid,
  limit_count int default 25
)
returns table (
  session_id uuid,
  mode text,
  status text,
  completed_at timestamptz,
  total_rounds int,
  user_points bigint,
  user_rank int,
  player_count bigint,
  won boolean
) as $$
  with session_totals as (
    select
      s.id as session_id,
      s.mode,
      s.status,
      s.completed_at,
      s.total_rounds,
      sc.user_id,
      coalesce(sum(sc.points_earned), 0) as user_points,
      rank() over (
        partition by s.id
        order by coalesce(sum(sc.points_earned), 0) desc
      ) as user_rank
    from public.sessions s
    join public.session_participants sp on sp.session_id = s.id
    left join public.scores sc on sc.session_id = s.id and sc.user_id = sp.user_id
    where s.status = 'completed'
      and sp.user_id = target_user_id
    group by s.id, s.mode, s.status, s.completed_at, s.total_rounds, sc.user_id
  )
  select
    st.session_id,
    st.mode,
    st.status,
    st.completed_at,
    st.total_rounds,
    st.user_points,
    st.user_rank::int,
    (
      select count(*) from public.session_participants
      where session_id = st.session_id
    ) as player_count,
    (st.user_rank = 1) as won
  from session_totals st
  where st.user_id = target_user_id
  order by st.completed_at desc nulls last
  limit limit_count;
$$ language sql stable security definer;

-- Search for users by username / display name (case-insensitive prefix)
create or replace function public.search_users(
  search_term text,
  limit_count int default 20
)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  total_score bigint,
  is_following boolean
) as $$
  select
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.total_score,
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.followee_id = u.id
    )
  from public.users u
  where u.id <> auth.uid()
    and (
      u.username ilike search_term || '%'
      or u.display_name ilike search_term || '%'
    )
  order by u.total_score desc
  limit limit_count;
$$ language sql stable security definer;
