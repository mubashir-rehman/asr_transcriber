# ┌───────────────────────────────────────────────────────────┐
# │  Stage 1: Build the Next.js frontend (Node builder)      │
# └───────────────────────────────────────────────────────────┘
FROM node:18-bullseye-slim AS frontend-builder

# Set a 1 GB memory cap for V8 to avoid OOM
ENV NODE_OPTIONS="--max_old_space_size=1024"

WORKDIR /app/asr-frontend

# Install deps & build
COPY asr-frontend/package.json asr-frontend/package-lock.json ./
RUN npm ci
COPY asr-frontend/ ./
RUN npm run build

# ┌───────────────────────────────────────────────────────────┐
# │  Stage 2: Assemble Python backend + bundle frontend      │
# └───────────────────────────────────────────────────────────┘
FROM python:3.9-slim-bullseye

# Install only what we need for Django + Postgres, plus git
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
 && rm -rf /var/lib/apt/lists/*

# Django environment
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=backend.settings \
    PORT_BACKEND=8000 \
    PORT_FRONTEND=3000

WORKDIR /app

# 1️⃣ Install Python deps
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2️⃣ Copy backend code
COPY backend/ ./

# 3️⃣ Copy built frontend + Node runtime from builder
#   - Copy the built .next/ and public/ folders
COPY --from=frontend-builder /app/asr-frontend/.next ./asr-frontend/.next
COPY --from=frontend-builder /app/asr-frontend/public ./asr-frontend/public
#   - Copy the built node_modules so we don’t need npm in this image
COPY --from=frontend-builder /app/asr-frontend/node_modules ./asr-frontend/node_modules
#   - Copy node & npm binaries (so `npm run start` still works)
COPY --from=frontend-builder /usr/local/bin/node /usr/local/bin/node
COPY --from=frontend-builder /usr/local/bin/npm  /usr/local/bin/npm
COPY --from=frontend-builder /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
#   - Copy package.json (needed by Next.js start)
COPY --from=frontend-builder /app/asr-frontend/package.json ./asr-frontend/package.json

# Expose both backend & frontend ports
EXPOSE ${PORT_BACKEND}
EXPOSE ${PORT_FRONTEND}

# Launch Django (Gunicorn) + Next.js in one container
CMD bash -lc "\
  gunicorn backend.wsgi:application --bind 0.0.0.0:${PORT_BACKEND} --workers=3 & \
  cd asr-frontend && npm run start -- -p ${PORT_FRONTEND} \
"
