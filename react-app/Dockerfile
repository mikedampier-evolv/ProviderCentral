# Provider Central — single container for Cloud Run.
#
# The Vite SPA and the Flask API ship together: stage 1 builds the static bundle
# with Node, stage 2 serves it from Flask alongside /api/*. One process, one
# port, which is what Cloud Run wants and what the cf-access-proxy sidecar
# assumes.

# ---------- Stage 1: build the SPA ----------
FROM node:22-alpine AS builder

WORKDIR /app

# Manifests first, so the dependency layer caches independently of source edits.
COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# `npm run build` is `tsc -b && vite build` — the typecheck is deliberate. A type
# error should fail the image build rather than ship a broken bundle.
RUN npm run build


# ---------- Stage 2: Python runtime ----------
FROM python:3.12-slim AS runner

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY server/requirements.txt ./server/requirements.txt
RUN pip install --no-cache-dir -r server/requirements.txt

COPY server/ ./server/
COPY --from=builder /app/dist ./dist

RUN adduser --system --uid 1001 appuser
USER appuser

# Local default only. Cloud Run injects PORT at runtime and that value wins —
# it becomes 8081 once the cf-access-proxy sidecar takes 8080 for itself.
# NEVER hardcode the port below: biorad-traceability pinned uvicorn to 8000 and
# had to be special-cased in the sidecar tooling because of it.
ENV PORT=8080
EXPOSE 8080

# Shell form on purpose, so $PORT expands at runtime rather than being baked in.
# `exec` hands PID 1 to gunicorn so Cloud Run's SIGTERM reaches it directly.
#
# --threads, not --workers: the Cortex Agent proxy holds an SSE connection open
# for the length of a chat response, so requests are long and IO-bound.
# --timeout 0 disables gunicorn's worker timeout (default 30s), which would
# otherwise sever a streaming response mid-answer. Cloud Run enforces its own
# request timeout, so this defers to that rather than fighting it.
CMD exec gunicorn \
      --chdir /app/server \
      --bind "0.0.0.0:$PORT" \
      --worker-class gthread \
      --workers 1 \
      --threads 16 \
      --timeout 0 \
      --access-logfile - \
      --error-logfile - \
      app:app
