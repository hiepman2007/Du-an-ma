create table public.study_workspaces (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  revision bigint not null default 0 check (revision >= 0),
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.study_notebooks (
  owner_id uuid not null references public.study_workspaces (owner_id) on delete cascade,
  notebook_id text not null check (notebook_id ~ '^[A-Za-z0-9_-]{1,120}$'),
  position integer not null check (position >= 0),
  document jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (owner_id, notebook_id)
);

alter table public.study_workspaces enable row level security;
alter table public.study_notebooks enable row level security;
revoke all on public.study_workspaces, public.study_notebooks from anon, authenticated;
grant select on public.study_workspaces, public.study_notebooks to authenticated;

create policy study_read_own_workspace on public.study_workspaces
  for select to authenticated using (owner_id = (select auth.uid()));

create policy study_read_own_notebooks on public.study_notebooks
  for select to authenticated using (owner_id = (select auth.uid()));

create function public.study_load_workspace()
returns jsonb
language sql stable security invoker
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'revision', workspace.revision,
      'snapshot', workspace.settings || jsonb_build_object('courses', coalesce((
        select jsonb_agg(notebook.document order by notebook.position)
        from public.study_notebooks notebook where notebook.owner_id = workspace.owner_id
      ), '[]'::jsonb))
    )
    from public.study_workspaces workspace where workspace.owner_id = (select auth.uid())
  ), jsonb_build_object('revision', 0, 'snapshot', jsonb_build_object('courses', '[]'::jsonb)));
$$;

create function public.study_save_workspace(p_snapshot jsonb, p_expected_revision bigint)
returns bigint
language plpgsql security definer
set search_path = ''
as $$
declare
  owner uuid := auth.uid();
  courses jsonb;
  next_revision bigint;
begin
  if owner is null then
    raise sqlstate 'PT401' using message = 'Sign in to save a workspace';
  end if;
  if jsonb_typeof(p_snapshot) is distinct from 'object' or p_expected_revision is null then
    raise sqlstate 'PT400' using message = 'Invalid workspace';
  end if;
  courses := coalesce(p_snapshot->'courses', '[]'::jsonb);
  if jsonb_typeof(courses) is distinct from 'array' then
    raise sqlstate 'PT400' using message = 'Invalid notebook list';
  end if;
  if exists (
    select 1 from jsonb_array_elements(courses) entry
    where jsonb_typeof(entry) is distinct from 'object'
      or jsonb_typeof(entry->'id') is distinct from 'string'
      or entry->>'id' !~ '^[A-Za-z0-9_-]{1,120}$'
  ) or exists (
    select 1 from jsonb_array_elements(courses) entry group by entry->>'id' having count(*) > 1
  ) then
    raise sqlstate 'PT400' using message = 'Invalid or duplicate notebook ID';
  end if;

  insert into public.study_workspaces (owner_id) values (owner) on conflict do nothing;
  update public.study_workspaces workspace
  set settings = p_snapshot - 'courses', revision = workspace.revision + 1, updated_at = now()
  where workspace.owner_id = owner and workspace.revision = p_expected_revision
  returning workspace.revision into next_revision;
  if next_revision is null then
    raise sqlstate 'PT409' using message = 'Workspace changed on another device';
  end if;

  insert into public.study_notebooks as existing (owner_id, notebook_id, position, document)
  select owner, entry->>'id', (ordinality - 1)::integer, entry
  from jsonb_array_elements(courses) with ordinality as notebook(entry, ordinality)
  on conflict (owner_id, notebook_id) do update
  set position = excluded.position, document = excluded.document, updated_at = now()
  where (existing.position, existing.document) is distinct from (excluded.position, excluded.document);

  delete from public.study_notebooks notebook
  where notebook.owner_id = owner
    and not exists (select 1 from jsonb_array_elements(courses) entry where entry->>'id' = notebook.notebook_id);
  return next_revision;
end;
$$;

revoke execute on function public.study_load_workspace() from public, anon;
revoke execute on function public.study_save_workspace(jsonb, bigint) from public, anon;
grant execute on function public.study_load_workspace() to authenticated;
grant execute on function public.study_save_workspace(jsonb, bigint) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('study-sources', 'study-sources', false, 10485760, array['application/pdf','image/jpeg','image/png','image/webp']);

create policy study_upload_own_sources on storage.objects
  for insert to authenticated with check (
    bucket_id = 'study-sources' and cardinality(storage.foldername(name)) = 2
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.study_notebooks notebook
      where notebook.owner_id = (select auth.uid()) and notebook.notebook_id = (storage.foldername(name))[2]
    )
  );

create policy study_read_own_sources on storage.objects
  for select to authenticated using (
    bucket_id = 'study-sources' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy study_delete_own_sources on storage.objects
  for delete to authenticated using (
    bucket_id = 'study-sources' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create table public.study_usage (
  id bigint generated always as identity primary key,
  owner_id uuid references auth.users (id) on delete set null,
  category text not null check (category in ('model', 'search')),
  task text not null,
  created_at timestamptz not null default now(),
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  cached_tokens integer check (cached_tokens >= 0)
);

create index study_usage_category_time on public.study_usage (category, created_at);
create index study_usage_owner_category_time on public.study_usage (owner_id, category, created_at);
alter table public.study_usage enable row level security;
revoke all on public.study_usage from anon, authenticated;
grant select, insert, update on public.study_usage to service_role;
grant usage on sequence public.study_usage_id_seq to service_role;

create function public.study_reserve_usage(
  p_owner uuid, p_category text, p_task text,
  p_owner_daily integer, p_project_daily integer, p_project_per_minute integer
)
returns bigint
language plpgsql security invoker
set search_path = ''
as $$
declare
  day_start timestamptz := date_trunc('day', statement_timestamp(), 'UTC');
  minute_start timestamptz := statement_timestamp() - interval '1 minute';
  reservation bigint;
begin
  if p_category not in ('model', 'search') or p_owner is null
    or least(p_owner_daily, p_project_daily, p_project_per_minute) < 1 then
    raise sqlstate 'PT400' using message = 'Invalid quota configuration';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('study_usage_' || p_category, 0));
  if (select count(*) from public.study_usage where category = p_category and owner_id = p_owner and created_at >= day_start) >= p_owner_daily
    or (select count(*) from public.study_usage where category = p_category and created_at >= day_start) >= p_project_daily
    or (select count(*) from public.study_usage where category = p_category and created_at >= minute_start) >= p_project_per_minute then
    raise sqlstate 'PT429' using message = 'Study quota exhausted';
  end if;

  insert into public.study_usage (owner_id, category, task)
  values (p_owner, p_category, left(p_task, 100)) returning id into reservation;
  return reservation;
end;
$$;

revoke execute on function public.study_reserve_usage(uuid, text, text, integer, integer, integer) from public, anon, authenticated;
grant execute on function public.study_reserve_usage(uuid, text, text, integer, integer, integer) to service_role;
