create extension if not exists pgcrypto;

create table if not exists public.sensor_readings (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  accel_x double precision,
  accel_y double precision,
  accel_z double precision,
  speed double precision,
  lat double precision,
  lng double precision,
  altitude double precision,
  gps_accuracy double precision,
  orientation double precision,
  impact_force double precision,
  total_acceleration double precision,
  temperature double precision,
  humidity double precision,
  pressure double precision,
  battery_voltage double precision,
  timestamp timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_sensor_readings_device_time
  on public.sensor_readings (device_id, timestamp desc);

create index if not exists idx_sensor_readings_geo_time
  on public.sensor_readings (timestamp desc, lat, lng);

create table if not exists public.trip_summaries (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  trip_id text not null unique,
  start_time timestamptz not null,
  end_time timestamptz not null,
  total_readings integer not null default 0,
  distance_km double precision not null default 0,
  avg_speed double precision not null default 0,
  max_speed double precision not null default 0,
  max_g_force double precision not null default 0,
  crash_event_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_trip_summaries_device_start
  on public.trip_summaries (device_id, start_time desc);

create table if not exists public.crash_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  device_id text not null,
  lat double precision,
  lng double precision,
  speed double precision,
  impact_force double precision,
  total_acceleration double precision,
  parameter_history jsonb not null default '[]'::jsonb,
  timestamp timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_crash_events_device_time
  on public.crash_events (device_id, timestamp desc);

create index if not exists idx_crash_events_event_id
  on public.crash_events (event_id);

alter table public.sensor_readings enable row level security;
alter table public.trip_summaries enable row level security;
alter table public.crash_events enable row level security;

drop policy if exists "client can insert sensor_readings" on public.sensor_readings;
create policy "client can insert sensor_readings"
on public.sensor_readings
for insert
to anon, authenticated
with check (true);

drop policy if exists "client can read sensor_readings" on public.sensor_readings;
create policy "client can read sensor_readings"
on public.sensor_readings
for select
to anon, authenticated
using (true);

drop policy if exists "client can insert trip_summaries" on public.trip_summaries;
create policy "client can insert trip_summaries"
on public.trip_summaries
for insert
to anon, authenticated
with check (true);

drop policy if exists "client can read trip_summaries" on public.trip_summaries;
create policy "client can read trip_summaries"
on public.trip_summaries
for select
to anon, authenticated
using (true);

drop policy if exists "client can insert crash_events" on public.crash_events;
create policy "client can insert crash_events"
on public.crash_events
for insert
to anon, authenticated
with check (true);

drop policy if exists "client can read crash_events" on public.crash_events;
create policy "client can read crash_events"
on public.crash_events
for select
to anon, authenticated
using (true);

drop policy if exists "service role can manage sensor_readings" on public.sensor_readings;
create policy "service role can manage sensor_readings"
on public.sensor_readings
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role can manage trip_summaries" on public.trip_summaries;
create policy "service role can manage trip_summaries"
on public.trip_summaries
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role can manage crash_events" on public.crash_events;
create policy "service role can manage crash_events"
on public.crash_events
for all
to service_role
using (true)
with check (true);
