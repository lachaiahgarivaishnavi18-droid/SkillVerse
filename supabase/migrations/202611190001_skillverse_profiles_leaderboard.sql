create table public.skillverse_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text check (char_length(full_name) between 1 and 120)
);

alter table public.skillverse_profiles enable row level security;
revoke all on public.skillverse_profiles from public, anon, authenticated;
grant select on public.skillverse_profiles to authenticated;
create policy "Read own profile" on public.skillverse_profiles
  for select to authenticated using ((select auth.uid()) = id);

create function public.skillverse_sync_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.email is not null then
    insert into public.skillverse_profiles (id, email, full_name)
    values (
      new.id,
      new.email,
      case when jsonb_typeof(new.raw_user_meta_data -> 'full_name') = 'string'
        then nullif(left(btrim(new.raw_user_meta_data ->> 'full_name'), 120), '')
      end
    )
    on conflict (id) do update
      set email = excluded.email, full_name = excluded.full_name;
  else
    delete from public.skillverse_profiles where id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.skillverse_sync_profile() from public, anon, authenticated;

create trigger skillverse_sync_profile
after insert or update of email, raw_user_meta_data on auth.users
for each row execute function public.skillverse_sync_profile();

insert into public.skillverse_profiles (id, email, full_name)
select id, email,
  case when jsonb_typeof(raw_user_meta_data -> 'full_name') = 'string'
    then nullif(left(btrim(raw_user_meta_data ->> 'full_name'), 120), '')
  end
from auth.users where email is not null
on conflict (id) do nothing;

create table public.skillverse_point_events (
  user_id uuid not null references public.skillverse_profiles(id) on delete cascade,
  source text not null check (source in ('quiz', 'assessment', 'mock_interview')),
  result_id text not null,
  points integer not null check (points >= 0),
  completed_at timestamptz not null default now(),
  primary key (user_id, source, result_id)
);
create index skillverse_point_events_completed_at
  on public.skillverse_point_events (completed_at, user_id);

alter table public.skillverse_point_events enable row level security;
revoke all on public.skillverse_point_events from public, anon, authenticated;
grant select, insert on public.skillverse_point_events to service_role;

create function public.skillverse_leaderboard(requested_period text)
returns table(full_name text, points bigint, rank bigint, is_you boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  period_start timestamptz;
begin
  if viewer is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  case requested_period
    when 'global' then period_start := '-infinity'::timestamptz;
    when 'weekly' then period_start := date_trunc('week', now(), 'UTC');
    when 'monthly' then period_start := date_trunc('month', now(), 'UTC');
    else raise exception 'Unknown leaderboard period' using errcode = '22023';
  end case;

  return query
    with totals as (
      select e.user_id, sum(e.points) as score
      from public.skillverse_point_events e
      where e.completed_at >= period_start and e.completed_at <= now()
      group by e.user_id
    ), ranked as (
      select p.id, p.full_name, t.score,
        rank() over (order by t.score desc) as position,
        row_number() over (order by t.score desc, p.id) as list_position
      from totals t
      join public.skillverse_profiles p on p.id = t.user_id
      where p.full_name is not null and t.score > 0
    ), visible as (
      select r.full_name, r.score, r.position, r.id = viewer as own, r.list_position
      from ranked r where r.list_position <= 10 or r.id = viewer
      union all
      select p.full_name, coalesce(t.score, 0), null::bigint, true, null::bigint
      from public.skillverse_profiles p
      left join totals t on t.user_id = p.id
      where p.id = viewer and not exists (select 1 from ranked r where r.id = viewer)
    )
    select v.full_name, v.score, v.position, v.own
    from visible v order by v.list_position nulls last;
end;
$$;
revoke all on function public.skillverse_leaderboard(text) from public, anon, authenticated;
grant execute on function public.skillverse_leaderboard(text) to authenticated;
