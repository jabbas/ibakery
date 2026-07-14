# AGENTS.md

Guidance for AI agents working on iBakery — an online bakery ordering system (Polish-language product).

## Layout

- `backend/` — Python FastAPI + async SQLAlchemy + PostgreSQL, Alembic migrations
- `artisan/` — Flutter **web-only** staff panel (pubspec package name is `baker` — rename remnant)
- `client/` — Flutter **web-only** customer app
- `baker/` — **dead legacy dir** (stale build output only). The staff panel lives in `artisan/`.
- `helm/` — umbrella chart; subcharts in `helm/charts/{backend,artisan,client}` via `file://` deps

**Stale docs warning**: `README.md` predates the `baker/`→`artisan/` rename. `baker/` is a **dead legacy dir** (stale build output only) — the staff panel lives in `artisan/`. Trust `helm/` over README for chart structure.

## Commands

Backend (from `backend/`):

```bash
docker-compose up -d postgres              # DB first (ibakery/ibakery123 on :5432)
uvicorn app.main:app --reload              # dev server (auto-runs migrations, see gotchas)
alembic upgrade head                       # manual migration (rarely needed — startup does it)
alembic revision --autogenerate -m "msg"   # new migration (target_metadata is wired)
ruff check .                               # lint
```

- ruff and pytest live in `backend/requirements-dev.txt` — install with `pip install -r requirements.txt -r requirements-dev.txt`.
- `tests/` has a smoke test (`tests/test_health.py`); coverage is minimal.
- Alembic needs a reachable Postgres: `env.py` builds the URL from app settings and converts `postgresql+asyncpg://` → `postgresql://` for sync migrations.

Flutter (from `client/` or `artisan/`):

```bash
flutter run -d chrome
flutter test --platform chrome             # plain `flutter test` exits 79 "No tests ran" — apps are web-only (dart:js_interop), tests are @TestOn('chrome')
flutter analyze
```

- build_runner/riverpod_generator are declared as dev deps but **no `.g.dart` files exist** — don't expect or reference generated code.

Build & deploy (CI/CD — see docs/superpowers/specs/2026-07-13-cicd-design.md):

- Merges to `main` deploy automatically: checks → SemVer tag from Conventional
  Commits → images to ghcr.io → chart to https://jabbas.github.io/ibakery →
  version bump commit to flux-homeapps → Flux rolls out to the cluster.
- **Commits on main MUST follow Conventional Commits** (`fix:` patch, `feat:`
  minor, `feat!:`/`BREAKING CHANGE:` major; anything else defaults to patch).
- Rollback: `git revert` the bump commit in flux-homeapps, push, Flux downgrades.
- App secrets live in cluster Secret `ibakery-app-secrets` (ns `ibakery`), not in
  values: `kubectl create secret generic ibakery-app-secrets -n ibakery --from-literal=SECRET_KEY=... --from-literal=SMSAPI_TOKEN=... --from-literal=MAIL_USERNAME=... --from-literal=MAIL_PASSWORD=...`
- There is no local build script anymore (`build.sh` removed; it was macOS-only and used podman).

## Backend gotchas

- **Startup mutates the DB.** The FastAPI lifespan runs Alembic `upgrade head`, seeds default units, marks expired offers completed, and generates recurring-offer instances 14 days ahead. Booting the server changes data.
- DB URL: `DATABASE_URL` env var, or computed from `PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE` (CloudNativePG secret in k8s). Settings load from `backend/.env` (pydantic-settings).
- Route dependency order: request data → `db: AsyncSession = Depends(get_db)` → auth. Protected routes use `get_current_baker`; assign to `_` when unused.
- Avoid N+1: each router defines a `_xxx_query()` helper with `selectinload()` chains. Create pattern: `db.add()` → `await db.flush()` (to get id) → add related rows → `commit()` → `db.expire_all()` → reload via the eager query.
- Errors: `HTTPException` with **Polish** `detail` text. Re-raise `HTTPException` as-is; catch other exceptions and convert to 500. Log with bracketed op tags and `exc_info=True`: `logger.error(f"[CREATE_PRODUCT] EXCEPTION: {e}", exc_info=True)`.
- Style: `T | None` not `Optional[T]`, `list[T]` not `List[T]`; docstrings only for complex ops, brief and in Polish.

## Flutter gotchas

- Web only — no mobile/desktop platform dirs; don't add them.
- Riverpod 3.x: `Provider` for services, `FutureProvider` for fetches, `NotifierProvider` for mutable state; `ConsumerWidget` + `.when()` for async UI.
- API base URL comes from `web/config.js` (`API_URL`), overridden by ConfigMap in k8s — not hardcoded in Dart (README's `baseUrl` instruction is stale).
- artisan stores JWT in `flutter_secure_storage` and injects `Authorization: Bearer` via a Dio interceptor; client has no auth.
- User-facing strings in **Polish**. On API errors, extract the backend's Polish `detail` from the DioException body (regex on `"detail"`) before falling back to a generic message; show via SnackBar in artisan.

## Domain model

Products have recipes (ingredients + quantities) and optional size variants (% of base recipe). Offers are time-limited with pickup date/time window and order deadline; recurring offers auto-generate instances. Orders are placed **without customer registration** against offer items, with a pickup point selection. Only bakers (staff) authenticate.
