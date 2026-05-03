# Supabase Setup

This project uses Supabase only for the cold-path relational data layer:

- `sensor_readings`
- `trip_summaries`
- `crash_events`

Firebase remains the primary backend for:

- authentication
- live telemetry
- hotspots
- training labels
- model file storage

## 1. Create a new Supabase project

Create a fresh project in the Supabase dashboard.

After the project is ready, open:

- `Project Settings -> API`

Copy:

- `Project URL`
- `anon public key`

## 2. Create the database tables

Open the Supabase SQL editor and run:

- [supabase/schema.sql](D:/ambulance_v2/supabase/schema.sql)

This creates the three tables expected by the app and adds indexes.

## 3. Configure the Flutter app

This repo now reads Supabase config from Dart defines instead of hardcoded keys.

Use:

```powershell
flutter run ^
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

For web builds:

```powershell
flutter build web ^
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## 4. Expected table usage

`sensor_readings`
- high-volume cold-path telemetry batches

`trip_summaries`
- aggregated trip-level analytics

`crash_events`
- durable crash history with JSON parameter history

## 5. Important security note

This Flutter app currently writes directly with the public anon key.

The SQL schema above includes prototype `insert` policies for `anon` and `authenticated` so the current client can write.

That is acceptable for prototyping, but for production you should move Supabase writes behind a trusted backend such as:

- Supabase Edge Functions
- Firebase Cloud Functions
- Cloud Run

That lets you keep stricter Row Level Security and avoid exposing direct write access patterns from the client.

## 6. Current fallback behavior

If Supabase is not configured, the app now skips cold-path writes instead of crashing at startup.

Firebase-backed flows continue to work.
