-- =====================================================================
--  MorseLab : schéma Supabase (amis, défi du jour, bouteilles à la mer)
--  À coller en entier dans Supabase > SQL Editor > New query > Run.
--  Le script peut être relancé sans risque (idempotent).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- TABLES
-- ---------------------------------------------------------------------

-- Profil public d'un joueur (1 par compte)
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text not null check (char_length(btrim(username)) between 2 and 20),
  friend_code  text not null unique check (friend_code ~ '^[A-Z0-9]{6}$'),
  xp           int  not null default 0 check (xp >= 0),
  level        int  not null default 1 check (level >= 1),
  streak       int  not null default 0 check (streak >= 0),
  chars        int  not null default 2 check (chars between 2 and 41),
  lessons      int  not null default 0 check (lessons >= 0),
  last_active  date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Amitiés (stockées dans les deux sens : A->B et B->A)
create table if not exists public.friendships (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  friend_id  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

-- Bouteilles à la mer : un message Morse envoyé à un ami, qu'il doit décoder
create table if not exists public.challenges (
  id            uuid primary key default gen_random_uuid(),
  from_id       uuid not null references public.profiles(id) on delete cascade,
  to_id         uuid not null references public.profiles(id) on delete cascade,
  message       text not null check (char_length(message) between 1 and 40 and message ~ '^[A-Z0-9 .,?/=]+$'),
  wpm           int  not null default 15 check (wpm between 5 and 40),
  reply_to      uuid references public.challenges(id) on delete set null,
  created_at    timestamptz not null default now(),
  opened_at     timestamptz,
  completed_at  timestamptz,
  answer        text,
  score         int check (score between 0 and 100),
  check (from_id <> to_id)
);
create index if not exists challenges_to_idx   on public.challenges (to_id, created_at desc);
create index if not exists challenges_from_idx on public.challenges (from_id, created_at desc);

-- Résultats du défi du jour (1 essai par jour et par joueur)
create table if not exists public.daily_results (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  day        date not null,
  score      int  not null check (score between 0 and 100),
  time_ms    int  not null check (time_ms between 0 and 3600000),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- ---------------------------------------------------------------------
-- SÉCURITÉ (Row Level Security)
-- Lecture : soi-même et ses amis. Écriture : uniquement via les fonctions ci-dessous.
-- ---------------------------------------------------------------------

create or replace function public.is_friend(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.friendships where user_id = a and friend_id = b);
$$;

alter table public.profiles      enable row level security;
alter table public.friendships   enable row level security;
alter table public.challenges    enable row level security;
alter table public.daily_results enable row level security;

drop policy if exists "profils lisibles : moi et mes amis" on public.profiles;
create policy "profils lisibles : moi et mes amis" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_friend(auth.uid(), id));

drop policy if exists "amitiés lisibles : les miennes" on public.friendships;
create policy "amitiés lisibles : les miennes" on public.friendships
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "bouteilles lisibles : expéditeur ou destinataire" on public.challenges;
create policy "bouteilles lisibles : expéditeur ou destinataire" on public.challenges
  for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());

drop policy if exists "défi du jour lisible : moi et mes amis" on public.daily_results;
create policy "défi du jour lisible : moi et mes amis" on public.daily_results
  for select to authenticated
  using (user_id = auth.uid() or public.is_friend(auth.uid(), user_id));

-- Aucun accès pour les visiteurs non connectés
revoke all on public.profiles, public.friendships, public.challenges, public.daily_results from anon;
-- Les joueurs connectés lisent (filtré par RLS) mais n'écrivent que via les fonctions
revoke insert, update, delete on public.profiles, public.friendships, public.challenges, public.daily_results from authenticated;
grant select on public.profiles, public.friendships, public.challenges, public.daily_results to authenticated;

-- ---------------------------------------------------------------------
-- FONCTIONS (appelées par l'app avec supabase.rpc)
-- ---------------------------------------------------------------------

-- Crée le profil (ou change le pseudo) ; génère un code ami unique de 6 caractères
create or replace function public.ensure_profile(p_username text)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare r public.profiles; v_code text;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  p_username := btrim(p_username);
  if char_length(p_username) not between 2 and 20 then raise exception 'Le pseudo doit faire 2 à 20 caractères'; end if;

  update public.profiles set username = p_username, updated_at = now()
   where id = auth.uid() returning * into r;
  if found then return r; end if;

  loop
    select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1), '')
      into v_code from generate_series(1, 6);
    exit when not exists (select 1 from public.profiles where friend_code = v_code);
  end loop;

  insert into public.profiles (id, username, friend_code)
  values (auth.uid(), p_username, v_code) returning * into r;
  return r;
end $$;

-- Ajoute un ami grâce à son code (amitié réciproque immédiate)
create or replace function public.add_friend(p_code text)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare f public.profiles;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if not exists (select 1 from public.profiles where id = auth.uid()) then raise exception 'Crée d''abord ton profil'; end if;
  select * into f from public.profiles where friend_code = upper(btrim(p_code));
  if not found then raise exception 'Code ami introuvable'; end if;
  if f.id = auth.uid() then raise exception 'C''est ton propre code'; end if;
  if (select count(*) from public.friendships where user_id = auth.uid()) >= 100 then raise exception 'Liste d''amis pleine (100)'; end if;
  insert into public.friendships (user_id, friend_id)
  values (auth.uid(), f.id), (f.id, auth.uid())
  on conflict do nothing;
  return f;
end $$;

-- Retire un ami (dans les deux sens)
create or replace function public.remove_friend(p_friend uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.friendships
   where (user_id = auth.uid() and friend_id = p_friend)
      or (user_id = p_friend and friend_id = auth.uid());
$$;

-- Publie la progression du joueur (visible par ses amis)
create or replace function public.sync_progress(p_xp int, p_level int, p_streak int, p_chars int, p_lessons int)
returns void language sql security definer set search_path = public as $$
  update public.profiles set
    xp          = greatest(0, least(coalesce(p_xp, 0), 100000000)),
    level       = greatest(1, least(coalesce(p_level, 1), 10000)),
    streak      = greatest(0, least(coalesce(p_streak, 0), 100000)),
    chars       = greatest(2, least(coalesce(p_chars, 2), 41)),
    lessons     = greatest(0, least(coalesce(p_lessons, 0), 100000)),
    last_active = current_date,
    updated_at  = now()
  where id = auth.uid();
$$;

-- Jette une bouteille à la mer vers un ami
create or replace function public.send_challenge(p_to uuid, p_message text, p_wpm int default 15, p_reply_to uuid default null)
returns public.challenges language plpgsql security definer set search_path = public as $$
declare c public.challenges;
        v_msg text := upper(btrim(regexp_replace(coalesce(p_message, ''), '\s+', ' ', 'g')));
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if not public.is_friend(auth.uid(), p_to) then raise exception 'Vous n''êtes pas amis'; end if;
  if (select count(*) from public.challenges where from_id = auth.uid() and created_at > now() - interval '1 day') >= 30 then
    raise exception 'Trop de bouteilles aujourd''hui (30 max)';
  end if;
  if p_reply_to is not null and not exists (select 1 from public.challenges where id = p_reply_to and to_id = auth.uid()) then
    p_reply_to := null;
  end if;
  insert into public.challenges (from_id, to_id, message, wpm, reply_to)
  values (auth.uid(), p_to, v_msg, greatest(5, least(coalesce(p_wpm, 15), 40)), p_reply_to)
  returning * into c;
  return c;
end $$;

-- Marque une bouteille comme ouverte (le destinataire l'a ramassée)
create or replace function public.open_challenge(p_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.challenges set opened_at = coalesce(opened_at, now())
   where id = p_id and to_id = auth.uid();
$$;

-- Termine un défi : le score est calculé ici, caractère par caractère
create or replace function public.complete_challenge(p_id uuid, p_answer text)
returns public.challenges language plpgsql security definer set search_path = public as $$
declare c public.challenges; v_ans text; v_ok int := 0; i int;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  select * into c from public.challenges where id = p_id and to_id = auth.uid() for update;
  if not found then raise exception 'Bouteille introuvable'; end if;
  if c.completed_at is not null then return c; end if;

  v_ans := left(upper(btrim(regexp_replace(coalesce(p_answer, ''), '\s+', ' ', 'g'))), 60);
  for i in 1 .. char_length(c.message) loop
    if substr(v_ans, i, 1) = substr(c.message, i, 1) then v_ok := v_ok + 1; end if;
  end loop;

  update public.challenges set
    answer       = v_ans,
    score        = round(100.0 * v_ok / char_length(c.message)),
    completed_at = now(),
    opened_at    = coalesce(opened_at, now())
  where id = p_id returning * into c;
  return c;
end $$;

-- Enregistre le résultat du défi du jour (le premier essai compte)
create or replace function public.submit_daily(p_day date, p_score int, p_time_ms int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if p_day not between current_date - 1 and current_date + 1 then raise exception 'Jour invalide'; end if;
  insert into public.daily_results (user_id, day, score, time_ms)
  values (auth.uid(), p_day, greatest(0, least(p_score, 100)), greatest(0, least(p_time_ms, 3600000)))
  on conflict (user_id, day) do nothing;
end $$;

-- Droits d'exécution : seulement les joueurs connectés
revoke execute on function public.is_friend(uuid, uuid)                        from public, anon;
revoke execute on function public.ensure_profile(text)                         from public, anon;
revoke execute on function public.add_friend(text)                             from public, anon;
revoke execute on function public.remove_friend(uuid)                          from public, anon;
revoke execute on function public.sync_progress(int, int, int, int, int)       from public, anon;
revoke execute on function public.send_challenge(uuid, text, int, uuid)        from public, anon;
revoke execute on function public.open_challenge(uuid)                         from public, anon;
revoke execute on function public.complete_challenge(uuid, text)               from public, anon;
revoke execute on function public.submit_daily(date, int, int)                 from public, anon;

grant execute on function public.is_friend(uuid, uuid)                         to authenticated;
grant execute on function public.ensure_profile(text)                          to authenticated;
grant execute on function public.add_friend(text)                              to authenticated;
grant execute on function public.remove_friend(uuid)                           to authenticated;
grant execute on function public.sync_progress(int, int, int, int, int)        to authenticated;
grant execute on function public.send_challenge(uuid, text, int, uuid)         to authenticated;
grant execute on function public.open_challenge(uuid)                          to authenticated;
grant execute on function public.complete_challenge(uuid, text)                to authenticated;
grant execute on function public.submit_daily(date, int, int)                  to authenticated;
