-- Enable realtime for game session tables
-- Clients subscribe to these for live game updates
alter publication supabase_realtime add table public.sessions;
alter publication supabase_realtime add table public.session_participants;
alter publication supabase_realtime add table public.session_rounds;
alter publication supabase_realtime add table public.scores;
