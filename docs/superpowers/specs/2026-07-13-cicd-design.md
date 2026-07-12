# CI/CD for iBakery — Design

Date: 2026-07-13
Status: approved (design discussion in session; owner: jabbas)

## Context

iBakery (github.com/jabbas/ibakery, public, MIT) has three deployables: `backend/`
(FastAPI), `artisan/` and `client/` (Flutter web), packaged by a Helm umbrella chart
in `helm/` with subcharts `helm/charts/{backend,artisan,client}`. Today builds are
manual via `build.sh` (macOS-only BSD sed, podman, pushes to docker.io/jabbas) and
deploys are manual `helm upgrade`.

The target cluster is a Flux CD v2 homelab cluster managed via the
`flux-homeapps` repo (GitRepository `home-applications` in `flux-system`), where each
app is a directory with `namespace.yaml`, a source, a `HelmRelease`, and a
`kustomization.yaml` entry (see `applications/firecrawl/`). Conventions: HelmRelease
interval 1m, HelmRepository interval 24h, ingress class `traefik-external` for
`*.jabbas.eu`, secrets never in git, Renovate enabled.

## Goals

- Continuous deploy: every merge to `main` reaches the cluster automatically.
- Images and chart share one version; deploys are atomic and rollback is one revert.
- No OCI Helm charts and no charts-from-GitRepository: publish a classic https Helm
  repository. No bot commits on ibakery `main`.
- PR validation (lint + tests) for all three components.
- Remove the macOS/podman dependency of `build.sh`.

## Non-goals

- Staging environment / promotion flow (can be added later).
- Meaningful backend test coverage (only a smoke test to make the gate real).
- Changing Flux controllers or cluster bootstrap.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CI system | GitHub Actions | Repo lives on GitHub; free for public repos |
| Deploy trigger | Every merge to `main` | Owner preference (option B) |
| Image registry | `ghcr.io/jabbas/ibakery-{backend,artisan,client}` | `GITHUB_TOKEN` auth, no Docker Hub rate limits on cluster pulls |
| Chart delivery | Classic Helm repo: `index.yaml` on `gh-pages` (GitHub Pages), `.tgz` as GitHub Release assets, via chart-releaser (`cr`) | Owner rejects OCI charts and git-sourced charts; Pages works because repo is public |
| Deploy mechanism | CI commits a one-line `spec.chart.spec.version` bump to `flux-homeapps` | Deploy state lives in the GitOps repo; history = deploy log; rollback = revert |
| Versioning | `X.Y.<run_number>`, base `X.Y` read from a root `VERSION` file (initial content `0.1`) | Semver-valid, auto-incrementing, manual control over base |
| Version propagation | `version` + `appVersion` set inside the packaged chart; subchart image tags default to `appVersion` | No image-tag plumbing in HelmRelease values |

## CI workflow (ibakery repo)

One workflow file (`.github/workflows/ci.yml`) with check jobs and release jobs;
release jobs run only on pushes to `main` and `needs:` all check jobs.

### Check jobs — pull requests and pushes to main

On PRs the jobs are path-filtered (run only when the component changed). On `main`
pushes all checks run unconditionally — a release always builds all three images, so
everything must be validated regardless of what changed. All must pass:

- **backend**: Python 3.11+, `pip install -r requirements.txt -r requirements-dev.txt`,
  `ruff check .`, `pytest`.
- **artisan** / **client**: pinned stable Flutter via `subosito/flutter-action`,
  `flutter pub get`, `flutter analyze`, `flutter test`.

Prerequisites created during implementation:

- `backend/requirements-dev.txt` declaring `ruff` and `pytest` (currently undeclared).
- At least one backend smoke test (e.g. `GET /api/health`) — pytest exits with code 5
  when zero tests are collected, which would fail CI.
- `flutter analyze` and existing widget tests brought to green if currently failing.

### Release jobs — push to `main` only

Gated by `if: github.event_name == 'push'` and `needs:` on all check jobs.
Serialized with `concurrency: { group: release, cancel-in-progress: false }` so two
quick merges cannot interleave gh-pages index updates or bump versions out of order.

1. **Version**: `VERSION_TAG="$(cat VERSION).${{ github.run_number }}"` (e.g. `0.1.42`).
2. **Images**: build & push `ghcr.io/jabbas/ibakery-{backend,artisan,client}:$VERSION_TAG`
   for `linux/amd64` via buildx.
   - backend: `docker/build-push-action` on `backend/`, build-arg `APP_VERSION`.
   - artisan/client: `flutter build web --release --pwa-strategy none
     --base-href=<href> --dart-define=APP_VERSION=$VERSION_TAG` in CI, where
     `<href>` is `/artisan/` for artisan and `/` for client, then image from root
     `Dockerfile.flutter` with `BUILD_DIR`/`BASE_HREF` build-args — same flags as
     `build.sh` today.
3. **Chart**: set `version:` and `appVersion:` to `$VERSION_TAG` in `helm/Chart.yaml`
   and all three subchart `Chart.yaml`s (workspace only, never committed), then
   `helm package --dependency-update helm/`.
4. **Publish chart**: `cr upload` (GitHub Release `ibakery-$VERSION_TAG` with the
   `.tgz` asset) and `cr index` (regenerate and push `index.yaml` on `gh-pages`).
   Uses `GITHUB_TOKEN`.
5. **Deploy bump**: checkout `flux-homeapps` with the `FLUX_HOMEAPPS_TOKEN` secret,
   `yq` the HelmRelease `spec.chart.spec.version` to `$VERSION_TAG`, commit
   `ibakery $VERSION_TAG`, push to `main`.

Ordering guarantee: the flux-homeapps bump is the final step, so the GitOps repo never
references images or a chart version that failed to publish. Any earlier failure means
no deploy.

## Flux side (flux-homeapps repo, new `applications/ibakery/`)

- `namespace.yaml` — namespace `ibakery`.
- `repository.yaml` — `HelmRepository` `ibakery`, `url: https://jabbas.github.io/ibakery`,
  interval 24h (repo convention; the version bump itself triggers reconciliation).
- `release.yaml` — `HelmRelease` `ibakery`, chart `ibakery`, `version: <pinned>`
  (the line CI bumps), interval 1m, install/upgrade remediation retries 3 (repo
  convention). Values: current production values from `helm/values.yaml`
  (ingress `marta.jabbas.eu` / `traefik-external`, CNPG database block, artisan
  `/artisan/` basePath, `apiUrl: https://marta.jabbas.eu/api`).
- `applications/kustomization.yaml` — add the two new resources.

### Secrets

`SECRET_KEY`, SMSAPI token, and mail credentials move out of chart values into a
manually created cluster Secret in the `ibakery` namespace, consumed via the backend
chart's existing `envSecret` mechanism (same way PG* vars already come from the CNPG
secret). CI and git never carry application secrets. The `backend.env.SECRET_KEY`
entry currently in `helm/values.yaml` is removed.

## Chart adjustments (ibakery repo)

- Default image repositories in subchart values change from `docker.io/jabbas/...` to
  `ghcr.io/jabbas/...`.
- Verify subchart image tags and backend `APP_VERSION` env default to
  `.Chart.AppVersion` (build.sh relied on this; keep it — the packaged chart carries
  the correct `appVersion`).
- `build.sh` is deleted; local emergency builds are documented as manual
  `flutter build` + `podman build` in AGENTS.md if ever needed.

## One-time setup (manual)

1. Create empty `gh-pages` branch; enable GitHub Pages (branch `gh-pages`, root).
2. Fine-grained PAT, resource = `jabbas/flux-homeapps` only, permission
   Contents: read/write; store as Actions secret `FLUX_HOMEAPPS_TOKEN` in ibakery.
3. First published packages on ghcr.io: set visibility to public so the cluster can
   pull without an imagePullSecret.
4. Create the application Secret in the `ibakery` namespace on the cluster.
5. **Bootstrap order**: land and run the ibakery CI first so release `0.1.1` exists
   (images, GitHub Release, Pages index), then add the `applications/ibakery/`
   manifests to flux-homeapps pinned to that version. Never point Flux at a version
   that has not been published.
6. Remove the stale `baker`/`client` services from `docker-compose.yml` or leave for
   local dev (postgres + backend only) — cosmetic, not blocking.

## Failure handling & rollback

- CI failure at any step before the flux bump → nothing deployed; cluster unchanged.
- Bad release in production → `git revert` the bump commit in flux-homeapps; Flux
  downgrades to the previous chart (and therefore previous images) within ~1m.
- Helm upgrade failures on cluster → existing remediation retries (3) per repo
  convention; release stays on last good revision.
- GitHub Releases accumulate one entry per merge — acceptable; optional cleanup
  later is out of scope.

## Verification (definition of done)

1. PR touching only `backend/` runs only backend checks; failing ruff/pytest blocks merge.
2. Merge to `main` produces: three ghcr images tagged `X.Y.<run>`, GitHub Release
   `ibakery-X.Y.<run>` with chart `.tgz`, updated `index.yaml` on Pages
   (`helm repo add ibakery https://jabbas.github.io/ibakery && helm search repo ibakery`
   shows the version), and a one-line commit in flux-homeapps.
3. `flux get hr -n ibakery` shows the new chart version reconciled; app pods run the
   new images; `https://marta.jabbas.eu/api/version` returns `X.Y.<run>`.
4. Reverting the bump commit rolls the deployment back.
