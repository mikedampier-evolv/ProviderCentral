# CLAUDE.md

Guidance for Claude Code / Cortex Code working in this repo. `README.md` is the full
reference — this file covers what an agent needs that the README does not say, plus the
handful of places the README has gone stale.

## Orientation

- `react-app/` is the **only active frontend**. React 19 + Vite SPA plus a Flask proxy in
  `react-app/server/`. Everything else is reference or superseded.
- `streamlit/` is **superseded and broken** against the live database — it still queries the
  retired `HOSPITAL360_CUR/_ML` names. Do not "fix" a Streamlit page unless asked
  specifically; it is not what ships.
- `infrastructure/*.sql` describes the *original* five-database design that was never
  deployed. The live platform is a single `HOSPITAL_360` database. See the README's
  **Deployment Reality** table before writing any SQL, and note there is no
  `09_seed_facts.sql`, so the platform cannot be rebuilt end-to-end from these scripts.

## Local development

```bash
cd react-app
npm install
npm run setup:server   # python3.12 -m venv .venv + pip install -r server/requirements.txt
npm run dev            # Flask on :3001 and Vite on :5173, concurrently
```

The Flask server runs from `react-app/.venv`, **not** bare `python3` — every `npm` script
invokes `.venv/bin/python` explicitly. The README's `pip install -r server/requirements.txt`
line predates this and installs into the wrong interpreter.

`react-app/.env` is gitignored and holds the Snowflake account, warehouse, role, database,
and PAT. The PAT expires: a wall of `401 Unauthorized` in `server/flask.log` means regenerate
it. The app renders fine with a dead PAT — every data panel just errors.

`npm run build` (`tsc -b && vite build`) passes as of `370dc74`. The README's "Known Gaps"
entry claiming seven TypeScript errors is out of date.

## Deploying to GCP

This app is deployed as an **evolv demo**: one Cloud Run service in the shared host project
`evolv-platform-ops`, fronted by Cloudflare Access.

| | |
|---|---|
| Slug | `provider-central` |
| Region | `us-central1` |
| Gate | `cf-access` |
| URL | https://provider-central.evolvconsulting.ai |
| Owner | terraform, as `tf-demos-factory@evolv-platform-ops.iam.gserviceaccount.com` |

Deploys go through the **`evolv-demos` plugin** (`github.com/evolvconsulting/evolv-demos`,
cloned alongside this repo at `../evolv-demos`). Its skills are in `skills/<name>/SKILL.md` —
read `skills/update/SKILL.md` before deploying.

- **Ship code to the existing service** → `/evolv-demos:update provider-central`, which is
  one command:

  ```bash
  python3 ../evolv-demos/tools/deploy-app.py \
    --slug provider-central --region us-central1 --gate cf-access \
    --source react-app
  ```

  Add `--dry-run` to print the plan without mutating anything. Exit 0 is the only signal that
  it is safe to hand out the URL — the tool runs `verify-demo.py` as its last step.

- **Never hand-assemble `gcloud run deploy`.** This service is a *converted* demo: a
  `cf-access-proxy` sidecar holds the ports alongside the `app` container. `gcloud run deploy
  --source` replaces the container holding the ports — the **sidecar** — keeping its name and
  swapping its image. That silently removes the auth gate while every name-based check still
  passes, and it does not ship your code either. `deploy-app.py` makes that unrepresentable.

- This service has **no GCS manifest**, so the tooling falls back to reading region and gate
  from the service labels. Both are present. Pass `--region`/`--gate` explicitly anyway.

Gotchas that cost time once already:

- `$(/plugin path evolv-demos)` in the skill docs is a Cortex Code built-in, **not a shell
  command**. In a plain shell it expands to nothing and gcloud gets a bogus `/tools/...`
  path. Substitute the repo path (`../evolv-demos`).
- `gcloud` here is a federated Entra workforce identity that expires often
  (`invalid_grant: Refresh token has expired`). Re-auth:
  `gcloud auth login --login-config=../evolv-demos/tools/login-config.json`
- No default gcloud project is set — pass `--project=evolv-platform-ops` on every call.

## Conventions

- **`evolv` is always lowercase**, including at the start of a sentence. Reword rather than
  capitalize.
- The chat widget and its charts are on a **light** palette (`#F5F2ED` bubbles, `#D15635`
  accent). `react-app/src/components/VegaChart.tsx` themes the agent's Vega specs to match;
  mark colors still come from the agent's own spec, so a chart can arrive with colors this
  config does not override.
