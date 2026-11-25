# Cyvora Flutter Architecture

## Structure

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── app_dependencies.dart
│   ├── app_initializer.dart
│   └── app_routes.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── permissions/
│   ├── storage/
│   ├── theme/
│   └── widgets/
├── data/
│   ├── datasources/
│   └── repositories/
└── features/
    ├── authentication/
    │   ├── models/
    │   ├── presenters/
    │   └── views/
    ├── dashboard/
    │   ├── models/
    │   ├── presenters/
    │   └── views/
    ├── profile/
    │   ├── models/
    │   └── views/
    ├── scanner/
    │   └── models/
    └── splash/
        └── views/
```

Only folders used by the current application are created. Family, alerts, scan
history, and settings remain dashboard subviews because their existing widgets
share state and navigation owned by `DashboardScreen`.

The original top-level imports are retained as export-only compatibility
barrels. New code should import from `app/`, `core/`, `data/`, or
`features/`.

## MVP responsibilities

- **Models** in `features/*/models/` define feature entities, validation, and
  repository contracts. They contain no Flutter widgets.
- **Views** in `features/*/views/` render widgets and handle user interactions.
  Auth forms and dashboard screens use Presenters for operations.
- **Presenters** in `features/*/presenters/` coordinate repository calls and
  translate operation outcomes into feature-level results. The dashboard
  Presenter also coordinates local conversation persistence and scan-feedback
  counts.
- **Repositories** in `data/repositories/` implement feature contracts and
  normalize backend responses.
- **Data sources** in `data/datasources/` encapsulate Supabase Auth, screenshot
  extraction, and profile-photo selection. `core/storage/` wraps local
  preferences behind a small store interface.

The dashboard repository currently contains its Supabase query and response
mapping implementation in the repository class. It remains isolated from
feature views behind `DashboardRepository`; extracting its table-specific
operations into a dedicated Supabase dashboard data source is a follow-up
boundary improvement that can be performed without changing the contract.

## Data flow

```text
View → Presenter → feature repository contract → data repository/data source
    → Supabase or local/platform service → feature model
    → Presenter → View
```

### Dependency injection

`AppInitializer` initializes Flutter and Supabase once and returns
`AppDependencies`. The dependency container constructs the authentication and
dashboard Presenters and their repository implementations. `AppRoutes` passes
those dependencies to the auth gate and initial screen. Do not initialize
Supabase from a screen or create a backend client in a feature view.

### Navigation

`AppRoutes.home` is the application entry route. `AuthPresenter` exposes the
authentication-state stream and MFA operations to `AuthGate`; the gate routes
to sign-in, password recovery, MFA verification, or the dashboard. The existing
dashboard tab navigation remains local to the dashboard feature.

### Backend and platform integrations

- Supabase initialization and environment configuration live in
  `app/app_initializer.dart` and `core/constants/supabase_config.dart`.
- Auth operations, including signup metadata, email confirmation, password
  reset, password update, MFA factor checks, challenges, verification, and
  sign-out, go through the auth data source and repository.
- Scan, family, alert, profile, and trusted-intelligence operations use the
  `DashboardRepository` contract. Database tables, Edge Function names, and
  request/response shapes are unchanged.
- Android notification permissions and notification-channel operations remain
  in `core/permissions/`. Screenshot text extraction retains platform-specific
  native, Web, and stub implementations.
- Safety Assistant conversations and scan feedback counters remain local to the
  device through the preferences store. No conversation is sent to the server
  except when the user submits it for a response.

## Adding a feature

1. Define feature entities, validation, and the repository contract in
   `features/<name>/models/`.
2. Implement backend or platform access in `data/datasources/` and an adapter
   in `data/repositories/`.
3. Add a Presenter in `features/<name>/presenters/` and inject it from
   `AppDependencies`.
4. Build widgets in `features/<name>/views/`; keep backend and local-storage
   calls out of the View.
5. Add focused Presenter/repository tests and verify with `flutter analyze`,
   `flutter test`, and supported platform builds.

## Current migration notes

- No application visual redesign or database/schema change was made.
- Dashboard feature subviews and some transient loading/error state remain
  co-located in the existing large `DashboardScreen`. Continue extracting them
  incrementally, preserving its shared navigation and state semantics.
- Live Supabase connectivity was not exercised; platform builds and tests do
  not substitute for credentials-backed integration verification.
