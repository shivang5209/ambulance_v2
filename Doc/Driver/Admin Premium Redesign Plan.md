# RapidAid v2 Driver/Admin Premium Redesign Plan

## Summary
Redesign the active `Driver Ops` and `Admin` role shells to match the premium visual quality of the poster mock while preserving the existing product titles and core data flows. The implementation will add a shared light/dark design system, a user-facing theme toggle, upgraded dashboard/map/activity layouts, and refined interaction patterns for alerts and monitoring. The redesign will target the real live app structure built around `RoleShellScaffold`, `DriverRoleShellScreen`, and `AdminRoleShellScreen`.

## Implementation Changes
### 1. Shared shell and theme foundation
- Refactor `RoleShellScaffold` into a premium app shell with:
  - branded header layout
  - leading menu/icon area
  - notification/status action area
  - subtitle styling that preserves current titles
  - richer bottom navigation styling in both themes
- Add a persistent theme preference layer:
  - new app setting/service/provider for `system`, `light`, `dark`
  - default to system theme
  - expose a manual override toggle from settings surfaces
- Expand the current theme system so both light and dark are intentionally designed, not just color inversions:
  - dark: tactical emergency ops style based on current palette
  - light: bright medical-tech variant with soft gray/white surfaces and blue/orange status accents
- Standardize component tokens for:
  - page spacing
  - card radii
  - chart containers
  - section headers
  - status chips
  - warning banners
  - metric tiles
  - map card overlays
- Keep existing role names:
  - `Driver Ops`
  - `Admin`
- Refresh only subtitles/section labels where needed for polish, while preserving current screen identity.

### 2. Driver redesign
- Rebuild the driver dashboard to follow the poster composition:
  - top hotspot warning banner
  - telemetry grid with speed, impact force, acceleration, GPS lock, route progress, ETA, destination
  - accident risk prediction card with severity, type, trend
  - live map preview card with route and hotspot emphasis
  - compact charts for speed and impact trends
  - bottom operational health strip for incident watch, sync, vehicle, network
- Keep existing driver data sources and alert logic:
  - ML prediction
  - hotspot proximity
  - training record save
  - accident confirmation dialog
- Upgrade the accident confirmation UX:
  - visually aligned modal/sheet in both themes
  - consistent severity hierarchy
  - clearer primary/secondary actions
  - prevent visual interruption conflicts with dashboard updates
- Rework the driver map and activity tabs so they visually match the new dashboard language rather than feeling like secondary legacy screens.
- Ensure all driver layouts work on narrow phones first, then expand gracefully to tablet/web widths.

### 3. Admin redesign
- Redesign the admin shell into an operations center UI using the same design language:
  - mission-status header
  - key summary metrics
  - hotspot activity panels
  - telemetry/device monitoring cards
  - live map/heatmap emphasis
  - stronger hierarchy for actions like connect device, demo mode, management
- Keep current behavior:
  - Firestore-backed map events
  - hotspot loading
  - ESP32/demo monitoring
- Reframe admin tabs around an operations workflow:
  - overview/dashboard
  - map/intelligence
  - devices/activity
  - settings/control
- Improve map UX:
  - better loading, empty, and stale-data states
  - consistent hotspot legend/chips
  - clearer event severity signaling in both themes

### 4. Theme toggle and settings behavior
- Add a theme mode selector under the active settings surfaces for driver and admin:
  - `Use system setting`
  - `Light mode`
  - `Dark mode`
- Persist the selection locally so the app restores it on launch.
- Wire `MaterialApp.themeMode` to the stored preference instead of always using system mode.
- Keep the current dark/light theme support as the base integration point, but move final appearance control into the redesigned tokenized theme system.

### 5. Componentization strategy
- Extract reusable premium UI components rather than styling inline:
  - shell header
  - warning banner
  - metric tile
  - summary card
  - chart card
  - section title row
  - status pill
  - theme selector tile
- Prefer shared components for driver/admin where structure overlaps, with small role-specific wrappers for content.

## Public Interfaces / Behavior Changes
- Add a persisted theme preference model/service used by `MaterialApp.themeMode`.
- Add user-visible theme mode controls in settings.
- No backend schema changes.
- No changes to Supabase/Firebase contract shapes.
- No changes to accident prediction input/output interfaces.

## Test Plan
- Theme behavior:
  - app defaults to system mode on first run
  - manual switch to light persists across restart
  - manual switch to dark persists across restart
  - toggling theme updates shell, cards, banners, charts, and map overlays consistently
- Driver UI:
  - hotspot banner renders when proximity data exists
  - accident prediction card handles normal, near miss, and accident states
  - accident confirmation flow still opens and records labels as before
  - dashboard remains usable on phone and web widths
- Admin UI:
  - overview loads with and without live telemetry
  - map tab handles loading, empty, and populated states
  - demo/device controls remain accessible after redesign
- Regression checks:
  - role navigation still works from login/role selection
  - bottom navigation still switches tabs correctly
  - web build still uses ML fallback and does not import `dart:ffi`
  - existing Firebase/Supabase initialization remains unchanged

## Assumptions
- First pass covers only the active `Driver` and `Admin` role shells.
- Existing titles remain, with only subtitle/section polish allowed.
- The redesign may substantially change layout and interaction presentation, but not the underlying backend logic.
- Theme mode will support both system default and manual override.
- Hospital, dispatcher, and citizen/family screens are out of scope for this pass, but the shared shell/theme system should be built so those screens can adopt it later without another redesign architecture change.
