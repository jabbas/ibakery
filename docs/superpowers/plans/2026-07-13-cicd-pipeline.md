# iBakery CI/CD Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Continuous deployment for iBakery: every merge to `main` runs checks, publishes SemVer-tagged images to ghcr.io and a Helm chart to a GitHub Pages helm repo, then bumps one line in flux-homeapps so Flux rolls it out to the Talos cluster.

**Architecture:** One GitHub Actions workflow (path-filtered checks on PRs; on main: Conventional-Commit-derived SemVer tag → 3 images → packaged umbrella chart to gh-pages/Releases via chart-releaser → version bump commit to flux-homeapps). Flux consumes a classic `HelmRepository` at `https://jabbas.github.io/ibakery`.

**Tech Stack:** GitHub Actions, buildx, `subosito/flutter-action`, `mathieudutour/github-tag-action`, `helm/chart-releaser-action`, Helm umbrella chart, Flux CD v2, yq.

**Spec:** `docs/superpowers/specs/2026-07-13-cicd-design.md`

**Repos touched:** `/Users/jabbas/Projects/ibakery` (origin `github.com/jabbas/ibakery`) and `/Users/jabbas/Projects/flux-homeapps`.

**Commit discipline:** All commits on ibakery `main` MUST use Conventional Commit messages (the version bump is derived from them). Use pathspec-limited commits (`git commit -m "..." -- <paths>`) — the working tree has unrelated pre-staged `.gitignore` changes that must not be swept in.

---

### Task 1: Backend dev dependencies + smoke test

**Files:**
- Create: `backend/requirements-dev.txt`
- Create: `backend/tests/test_health.py`
- Modify: `AGENTS.md` (dev-deps note; done in Task 7)

- [ ] **Step 1: Create `backend/requirements-dev.txt`**

```
ruff==0.14.4
pytest==8.4.2
```

- [ ] **Step 2: Create venv and install deps**

```bash
cd /Users/jabbas/Projects/ibakery/backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
```

Expected: exits 0. (If `.venv` already exists, reuse it.)

- [ ] **Step 3: Write the smoke test**

`backend/tests/test_health.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


def test_health():
    # No `with` block: avoids running the lifespan (migrations/DB) — no database needed
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
```

- [ ] **Step 4: Run pytest, verify it collects and passes**

```bash
cd /Users/jabbas/Projects/ibakery/backend && .venv/bin/pytest -v
```

Expected: `1 passed`. (Before this task pytest exited with code 5 = no tests collected; that would fail CI.)

- [ ] **Step 5: Run ruff and fix findings**

```bash
cd /Users/jabbas/Projects/ibakery/backend && .venv/bin/ruff check .
```

If findings: run `.venv/bin/ruff check . --fix`, review the diff (`git diff backend/`), fix remaining findings manually (typical: unused imports). Re-run until exit 0.

- [ ] **Step 6: Verify `.venv` is gitignored**

```bash
cd /Users/jabbas/Projects/ibakery && git status --short backend/ | grep -c '.venv'
```

Expected: `0`. If `.venv` shows up, add `.venv/` to `backend/.gitignore`.

- [ ] **Step 7: Commit**

```bash
cd /Users/jabbas/Projects/ibakery
git add backend/requirements-dev.txt backend/tests/test_health.py
git commit -m "test: add backend smoke test and dev requirements" -- backend/
```

(If ruff fixed files, `git add` those too before committing.)

### Task 2: Flutter checks green

**Files:**
- Possibly modify: `artisan/lib/**`, `client/lib/**`, `*/test/widget_test.dart` (only if analyze/test fail)

- [ ] **Step 1: Run checks for artisan**

```bash
cd /Users/jabbas/Projects/ibakery/artisan
flutter pub get && flutter analyze && flutter test
```

Expected: `No issues found!` and `All tests passed!`.

- [ ] **Step 2: Run checks for client**

```bash
cd /Users/jabbas/Projects/ibakery/client
flutter pub get && flutter analyze && flutter test
```

Expected: same.

- [ ] **Step 3: Fix failures if any**

Fix reported analyzer issues / failing tests in the affected app. Keep fixes minimal — do not refactor. Re-run Step 1/2 until green. If everything was already green, skip Step 4.

- [ ] **Step 4: Commit (only if files changed)**

```bash
cd /Users/jabbas/Projects/ibakery
git add artisan/lib artisan/test client/lib client/test
git commit -m "fix: make flutter analyze and tests pass" -- artisan/ client/
```

### Task 3: Chart adjustments (ghcr + no secrets in values)

**Files:**
- Modify: `helm/charts/backend/values.yaml:4,13-14`
- Modify: `helm/charts/artisan/values.yaml:10`
- Modify: `helm/charts/client/values.yaml:7`
- Modify: `helm/values.yaml` (remove `backend.env.SECRET_KEY`)

- [ ] **Step 1: Point image repositories at ghcr**

In `helm/charts/backend/values.yaml` change:

```yaml
image:
  repository: ghcr.io/jabbas/ibakery-backend
```

In `helm/charts/artisan/values.yaml`:

```yaml
image:
  repository: ghcr.io/jabbas/ibakery-artisan
```

In `helm/charts/client/values.yaml`:

```yaml
image:
  repository: ghcr.io/jabbas/ibakery-client
```

- [ ] **Step 2: Remove SECRET_KEY defaults from values**

In `helm/charts/backend/values.yaml` replace:

```yaml
# Environment variables
env:
  SECRET_KEY: "change-me-in-production"
```

with:

```yaml
# Environment variables (non-secret only; secrets go via envSecret)
env: {}
```

In `helm/values.yaml` delete these two lines from the `backend:` block:

```yaml
  env:
    SECRET_KEY: "change-me-in-production"
```

- [ ] **Step 3: Sanity-render the chart**

```bash
cd /Users/jabbas/Projects/ibakery
helm lint helm/ && helm template ibakery helm/ --dependency-update >/dev/null && echo RENDER_OK
```

Expected: `RENDER_OK` (lint may print info-level notes; errors are failures).
Verify tag defaulting is intact: `helm template ibakery helm/ | grep 'image:'` shows `ghcr.io/jabbas/ibakery-*:0.0.1` (current committed appVersion).

- [ ] **Step 4: Commit**

```bash
cd /Users/jabbas/Projects/ibakery
git add helm/
git commit -m "chore: switch charts to ghcr images, drop secret defaults from values" -- helm/
```

### Task 4: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow**

`.github/workflows/ci.yml` — complete file:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: write   # push tags, create releases, push gh-pages
  packages: write   # push to ghcr.io

concurrency:
  group: ${{ github.event_name == 'push' && 'release' || format('pr-{0}', github.ref) }}
  cancel-in-progress: false

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      artisan: ${{ steps.filter.outputs.artisan }}
      client: ${{ steps.filter.outputs.client }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - 'backend/**'
            artisan:
              - 'artisan/**'
              - 'Dockerfile.flutter'
              - 'static-web-server.toml'
            client:
              - 'client/**'
              - 'Dockerfile.flutter'
              - 'static-web-server.toml'

  check-backend:
    needs: changes
    # On main pushes always run (a release builds all images); on PRs only when changed
    if: github.event_name == 'push' || needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
          cache: pip
          cache-dependency-path: backend/requirements*.txt
      - run: pip install -r requirements.txt -r requirements-dev.txt
        working-directory: backend
      - run: ruff check .
        working-directory: backend
      - run: pytest -v
        working-directory: backend

  check-flutter:
    needs: changes
    if: >-
      github.event_name == 'push' ||
      needs.changes.outputs.artisan == 'true' ||
      needs.changes.outputs.client == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: [artisan, client]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
        working-directory: ${{ matrix.app }}
      - run: flutter analyze
        working-directory: ${{ matrix.app }}
      - run: flutter test
        working-directory: ${{ matrix.app }}

  version:
    if: github.event_name == 'push'
    needs: [check-backend, check-flutter]
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.tag.outputs.new_version }}
      tag: ${{ steps.tag.outputs.new_tag }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Compute SemVer from Conventional Commits and push tag
        id: tag
        uses: mathieudutour/github-tag-action@v6.2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          release_branches: main
          default_bump: patch

  image-backend:
    needs: version
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: backend
          platforms: linux/amd64
          push: true
          tags: ghcr.io/jabbas/ibakery-backend:${{ needs.version.outputs.version }}
          build-args: |
            APP_VERSION=${{ needs.version.outputs.version }}

  image-flutter:
    needs: version
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - app: artisan
            base_href: /artisan/
          - app: client
            base_href: /
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
        working-directory: ${{ matrix.app }}
      - name: Build Flutter web
        run: >-
          flutter build web --release --pwa-strategy none
          --base-href=${{ matrix.base_href }}
          --dart-define=APP_VERSION=${{ needs.version.outputs.version }}
        working-directory: ${{ matrix.app }}
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          file: Dockerfile.flutter
          platforms: linux/amd64
          push: true
          tags: ghcr.io/jabbas/ibakery-${{ matrix.app }}:${{ needs.version.outputs.version }}
          build-args: |
            BUILD_DIR=${{ matrix.app }}/build/web
            BASE_HREF=${{ matrix.base_href }}

  chart:
    needs: [version, image-backend, image-flutter]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Set chart versions
        env:
          V: ${{ needs.version.outputs.version }}
        run: |
          for f in helm/Chart.yaml helm/charts/backend/Chart.yaml helm/charts/artisan/Chart.yaml helm/charts/client/Chart.yaml; do
            yq -i ".version = strenv(V) | .appVersion = strenv(V)" "$f"
          done
      - name: Package umbrella chart
        run: |
          mkdir -p .cr-release-packages
          helm package helm/ --dependency-update -d .cr-release-packages
          ls -l .cr-release-packages
      - name: Configure git for chart-releaser
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
      - name: Upload release and update index on gh-pages
        uses: helm/chart-releaser-action@v1.7.0
        with:
          skip_packaging: true
          skip_existing: true
        env:
          CR_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  deploy-bump:
    needs: [version, chart]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: jabbas/flux-homeapps
          token: ${{ secrets.FLUX_HOMEAPPS_TOKEN }}
      - name: Bump ibakery chart version
        env:
          V: ${{ needs.version.outputs.version }}
        run: |
          yq -i '.spec.chart.spec.version = strenv(V)' applications/ibakery/release.yaml
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -am "ibakery ${V}"
          git push
```

- [ ] **Step 2: Validate workflow syntax locally**

```bash
cd /Users/jabbas/Projects/ibakery
yq '.jobs | keys' .github/workflows/ci.yml
```

Expected: list of 8 job names, no YAML parse error. (If `actionlint` is installed, also run `actionlint .github/workflows/ci.yml` — expected: no output.)

- [ ] **Step 3: Commit**

```bash
cd /Users/jabbas/Projects/ibakery
git add .github/workflows/ci.yml
git commit -m "ci: add build, release and deploy-bump pipeline" -- .github/
```

**Note for Task 6:** `deploy-bump` will fail on the very first release run because `applications/ibakery/release.yaml` does not exist in flux-homeapps yet (bootstrap order, per spec). That is expected — the first run's images/chart are still published; Task 6 creates the manifests pinned to that version, and subsequent runs bump normally.

### Task 5: One-time GitHub setup + first release

**Files:** none in the repo (repo settings, branch, tag). Requires `gh` CLI authenticated as jabbas.

- [ ] **Step 1 (USER ACTION): Create fine-grained PAT**

In GitHub UI: Settings → Developer settings → Fine-grained tokens → Generate new token. Resource owner `jabbas`, repository access: **only `jabbas/flux-homeapps`**, permissions: Contents = Read and write. Then store it:

```bash
cd /Users/jabbas/Projects/ibakery
gh secret set FLUX_HOMEAPPS_TOKEN --app actions
```

(paste the token when prompted)

- [ ] **Step 2: Create empty gh-pages branch (plumbing — does not touch the dirty worktree/index)**

```bash
cd /Users/jabbas/Projects/ibakery
empty_tree=$(git hash-object -t tree /dev/null)
commit=$(git commit-tree "$empty_tree" -m "chore: init helm repo branch")
git branch gh-pages "$commit"
git push origin gh-pages
```

- [ ] **Step 3: Enable GitHub Pages on gh-pages**

```bash
gh api -X POST repos/jabbas/ibakery/pages \
  -f "source[branch]=gh-pages" -f "source[path]=/" 2>/dev/null \
|| gh api -X PUT repos/jabbas/ibakery/pages \
  -f "source[branch]=gh-pages" -f "source[path]=/"
```

Expected: JSON response containing `"html_url": "https://jabbas.github.io/ibakery/"`.

- [ ] **Step 4: Seed SemVer baseline tag**

Tag the current pushed tip of main as the 0.1.0 baseline:

```bash
cd /Users/jabbas/Projects/ibakery
git fetch origin
git tag v0.1.0 "$(git rev-parse origin/main 2>/dev/null || git rev-parse HEAD)"
git push origin v0.1.0
```

- [ ] **Step 5: Push main and watch the first release**

```bash
cd /Users/jabbas/Projects/ibakery
git push origin main
gh run watch --exit-status || true
gh run list --workflow=CI --limit 1
```

Expected: check jobs, `version`, `image-*`, `chart` succeed. `deploy-bump` **fails** (release.yaml not in flux-homeapps yet — expected, see Task 4 note). Note the published version:

```bash
gh release list --limit 3
git fetch --tags && git tag --sort=-creatordate | head -3
```

Expected: a release like `ibakery-0.1.1` and tag `v0.1.1`. Record this version for Task 6 (referred to as `<FIRST_VERSION>`).

- [ ] **Step 6: Verify helm repo works**

```bash
helm repo add ibakery https://jabbas.github.io/ibakery
helm repo update ibakery
helm search repo ibakery
```

Expected: `ibakery/ibakery` with `CHART VERSION` = `<FIRST_VERSION>`. (Pages can take ~1 min to publish; retry once if 404.)

- [ ] **Step 7 (USER ACTION): Make ghcr packages public**

GitHub UI → jabbas profile → Packages → for each of `ibakery-backend`, `ibakery-artisan`, `ibakery-client`: Package settings → Change visibility → Public. Verify anonymously:

```bash
docker manifest inspect ghcr.io/jabbas/ibakery-backend:<FIRST_VERSION> >/dev/null && echo PUBLIC_OK
```

Expected: `PUBLIC_OK` (works without docker login).

### Task 6: Flux manifests in flux-homeapps

**Files (repo `/Users/jabbas/Projects/flux-homeapps`):**
- Create: `applications/ibakery/namespace.yaml`
- Create: `applications/ibakery/repository.yaml`
- Create: `applications/ibakery/release.yaml`
- Modify: `applications/kustomization.yaml`

- [ ] **Step 1: Create `applications/ibakery/namespace.yaml`**

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: ibakery
```

- [ ] **Step 2: Create `applications/ibakery/repository.yaml`**

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ibakery
  namespace: ibakery
spec:
  url: https://jabbas.github.io/ibakery
  interval: 24h
```

- [ ] **Step 3: Create `applications/ibakery/release.yaml`**

Replace `<FIRST_VERSION>` with the version recorded in Task 5 Step 5 (e.g. `0.1.1`):

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ibakery
  namespace: ibakery
spec:
  releaseName: ibakery
  chart:
    spec:
      chart: ibakery
      version: "<FIRST_VERSION>"
      sourceRef:
        kind: HelmRepository
        name: ibakery
        namespace: ibakery
  interval: 1m0s
  timeout: 10m0s
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    ingress:
      enabled: true
      className: "traefik-external"
      host: "marta.jabbas.eu"
    database:
      enabled: true
      cluster:
        instances: 2
        affinity:
          enablePodAntiAffinity: true
          topologyKey: kubernetes.io/hostname
        bootstrap:
          initdb:
            database: ibakery
            owner: ibakery
        storage:
          size: 1Gi
        backup:
          volumeSnapshot:
            className: democratic-csi
            online: true
            onlineConfiguration:
              waitForArchive: true
              immediateCheckpoint: true
        monitoring:
          enablePodMonitor: false
      scheduledBackup:
        schedule: "0 0 2 * * 1"
        backupOwnerReference: self
        method: volumeSnapshot
    backend:
      replicaCount: 1
      ingress:
        enabled: false
      envSecret:
        - name: PGHOST
          secretName: "{{ .Release.Name }}-db-app"
          key: host
        - name: PGPORT
          secretName: "{{ .Release.Name }}-db-app"
          key: port
        - name: PGUSER
          secretName: "{{ .Release.Name }}-db-app"
          key: username
        - name: PGPASSWORD
          secretName: "{{ .Release.Name }}-db-app"
          key: password
        - name: PGDATABASE
          secretName: "{{ .Release.Name }}-db-app"
          key: dbname
        - name: SECRET_KEY
          secretName: ibakery-app-secrets
          key: SECRET_KEY
        - name: SMSAPI_TOKEN
          secretName: ibakery-app-secrets
          key: SMSAPI_TOKEN
        - name: MAIL_USERNAME
          secretName: ibakery-app-secrets
          key: MAIL_USERNAME
        - name: MAIL_PASSWORD
          secretName: ibakery-app-secrets
          key: MAIL_PASSWORD
    artisan:
      replicaCount: 1
      ingress:
        enabled: false
      apiUrl: "https://marta.jabbas.eu/api"
      basePath: "/artisan/"
    client:
      replicaCount: 1
      ingress:
        enabled: false
      apiUrl: "https://marta.jabbas.eu/api"
```

(Values mirror `helm/values.yaml` in ibakery, minus the removed `SECRET_KEY` env, plus app secrets via `envSecret` — same mechanism as the PG* CNPG entries.)

- [ ] **Step 4: Register in `applications/kustomization.yaml`**

Add to `resources:` (keep existing firecrawl entries):

```yaml
  - ibakery/namespace.yaml
  - ibakery/repository.yaml
  - ibakery/release.yaml
```

- [ ] **Step 5 (USER ACTION): Create app secret on the cluster**

User must run (with real values):

```bash
kubectl create namespace ibakery --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic ibakery-app-secrets -n ibakery \
  --from-literal=SECRET_KEY='<random-long-string>' \
  --from-literal=SMSAPI_TOKEN='<token>' \
  --from-literal=MAIL_USERNAME='<smtp-user>' \
  --from-literal=MAIL_PASSWORD='<smtp-pass>'
```

- [ ] **Step 6: Validate and push**

```bash
cd /Users/jabbas/Projects/flux-homeapps
kubectl kustomize applications/ >/dev/null && echo KUSTOMIZE_OK
git add applications/ibakery applications/kustomization.yaml
git commit -m "Add ibakery application (chart <FIRST_VERSION>)"
git push
```

Expected: `KUSTOMIZE_OK`, push succeeds.

- [ ] **Step 7: Verify Flux rollout**

```bash
flux reconcile source git home-applications -n flux-system
flux get hr -n ibakery
kubectl get pods -n ibakery
curl -s https://marta.jabbas.eu/api/version
```

Expected: HelmRelease `ibakery` Ready=True at `<FIRST_VERSION>`; backend/artisan/client pods Running; version endpoint returns `{"version":"<FIRST_VERSION>"}`.

### Task 7: Retire build.sh, clean compose, update AGENTS.md

**Files (repo ibakery):**
- Delete: `build.sh`
- Modify: `docker-compose.yml` (remove dead `baker`/`client` services)
- Modify: `AGENTS.md` (Commands + gotchas sections)

- [ ] **Step 1: Delete build.sh**

```bash
cd /Users/jabbas/Projects/ibakery && git rm build.sh
```

- [ ] **Step 2: Remove dead compose services**

In `docker-compose.yml` delete the `baker:` and `client:` service blocks (lines 31-51), keeping `postgres`, `backend`, and `volumes:`.

- [ ] **Step 3: Update AGENTS.md**

Replace the "Build & deploy" part of the Commands section with:

```markdown
Build & deploy (CI/CD — see docs/superpowers/specs/2026-07-13-cicd-design.md):

- Merges to `main` deploy automatically: checks → SemVer tag from Conventional
  Commits → images to ghcr.io → chart to https://jabbas.github.io/ibakery →
  version bump commit to flux-homeapps → Flux rolls out.
- **Commits on main MUST follow Conventional Commits** (`fix:` patch, `feat:`
  minor, `feat!:`/`BREAKING CHANGE:` major; anything else defaults to patch).
- Rollback: `git revert` the bump commit in flux-homeapps.
- There is no local build script anymore; backend dev deps: `pip install -r
  requirements.txt -r requirements-dev.txt`.
```

Also update the stale-docs warning (compose services now cleaned) and delete the `./build.sh` reference and "macOS-only/podman" notes.

- [ ] **Step 4: Verify compose still valid**

```bash
cd /Users/jabbas/Projects/ibakery && docker-compose config >/dev/null && echo COMPOSE_OK
```

Expected: `COMPOSE_OK` (or use `podman-compose config` / `docker compose config`).

- [ ] **Step 5: Commit and push (triggers a release — that's fine)**

```bash
cd /Users/jabbas/Projects/ibakery
git add AGENTS.md docker-compose.yml
git commit -m "chore: retire build.sh, clean dead compose services, document CI/CD" -- build.sh docker-compose.yml AGENTS.md
git push origin main
gh run watch --exit-status
```

Expected: full pipeline green **including `deploy-bump`** this time (release.yaml now exists); flux-homeapps gets a bump commit; `flux get hr -n ibakery` shows the new patch version after ~1m.

### Task 8: End-to-end verification (definition of done)

- [ ] **Step 1: PR path filtering**

Create a branch with a backend-only whitespace change, open a PR:

```bash
cd /Users/jabbas/Projects/ibakery
git switch -c test/ci-paths
echo "# ci path filter test" >> backend/requirements-dev.txt
git commit -m "test: ci path filter check" -- backend/requirements-dev.txt
git push -u origin test/ci-paths
gh pr create --fill
gh pr checks --watch
```

Expected: `check-backend` runs; `check-flutter` is skipped; no release jobs. Then close without merging: `gh pr close test/ci-paths --delete-branch`.

- [ ] **Step 2: Confirm spec verification items**

- `gh release list` shows `ibakery-X.Y.Z` releases ✓
- `helm search repo ibakery` shows latest version ✓ (after `helm repo update`)
- flux-homeapps `git log --oneline -3` shows `ibakery X.Y.Z` bump commits ✓
- `curl -s https://marta.jabbas.eu/api/version` matches the latest tag ✓
- Rollback drill (optional): revert the last bump commit in flux-homeapps, push, watch Flux downgrade, then re-revert.

- [ ] **Step 3: Commit the plan checkboxes / state**

```bash
cd /Users/jabbas/Projects/ibakery
git add docs/superpowers/plans/2026-07-13-cicd-pipeline.md
git commit -m "docs: mark CI/CD plan executed" -- docs/
git push origin main
```
