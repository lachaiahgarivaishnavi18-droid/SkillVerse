create table public.skillverse_scoring_catalog (
  source text not null check (source in ('quiz', 'assessment', 'mock_interview')),
  question_id text not null,
  answer_index integer,
  primary key (source, question_id),
  check ((source = 'mock_interview') = (answer_index is null)),
  check (answer_index >= 0)
);

alter table public.skillverse_scoring_catalog enable row level security;
revoke all on public.skillverse_scoring_catalog from public, anon, authenticated;

-- Authentication comes from the caller's token. The expected ID binds queued
-- work to its original session even if the active account changes mid-request.
create function public.skillverse_submit_result(
  expected_user uuid, result_source text, answers jsonb
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  player uuid := auth.uid();
begin
  if player is null or player is distinct from expected_user
    or not exists (
      select 1 from auth.users u where u.id = player and u.email_confirmed_at is not null
    ) then
    raise exception 'Confirmed account required' using errcode = '42501';
  end if;

  if result_source is null or result_source not in ('quiz', 'assessment', 'mock_interview')
    or jsonb_typeof(answers) is distinct from 'object'
    or octet_length(answers::text) > 262144 then
    raise exception 'Invalid result' using errcode = '22023';
  end if;

  -- Every question earns credit once per account and source. Multiple-choice
  -- answers are graded here. Written mock credit represents self-review
  -- completion, independent of the user's own correctness rating.
  insert into public.skillverse_point_events (user_id, source, result_id, points)
  select player, c.source, 'question:' || c.question_id, 1
  from jsonb_each(answers) a
  join public.skillverse_scoring_catalog c
    on c.source = result_source and c.question_id = a.key
  where case
    when c.source = 'mock_interview' then a.value = 'true'::jsonb
    else a.value = to_jsonb(c.answer_index)
  end
  on conflict (user_id, source, result_id) do nothing;
end;
$$;
revoke all on function public.skillverse_submit_result(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.skillverse_submit_result(uuid, text, jsonb)
  to authenticated;

create or replace function public.skillverse_leaderboard(requested_period text)
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
      select p.id, p.full_name, coalesce(t.score, 0) as score,
        rank() over (order by coalesce(t.score, 0) desc) as position,
        row_number() over (order by coalesce(t.score, 0) desc, p.id) as list_position
      from public.skillverse_profiles p
      join auth.users u on u.id = p.id and u.email_confirmed_at is not null
      left join totals t on t.user_id = p.id
      where p.full_name is not null
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
