# ┌───────────────────────────────────────────────────────────┐
# │ Stage 1: Build & static-export Next.js frontend         │
# └───────────────────────────────────────────────────────────┘
FROM node:18-bullseye-slim AS frontend-builder

# Increase V8 heap to avoid OOM on constrained build hosts
ENV NODE_OPTIONS="--max_old_space_size=1024"

WORKDIR /app/asr-frontend

# Install deps
COPY asr-frontend/package.json asr-frontend/package-lock.json ./
RUN npm ci

# Copy source & build + export
COPY asr-frontend/ ./
RUN npm run build && npm run export

# ┌───────────────────────────────────────────────────────────┐
# │ Stage 2: Python backend + serve static frontend assets  │
# └───────────────────────────────────────────────────────────┘
FROM python:3.9-slim-bullseye

# Install only build tools and system libs needed by your Python deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# Set Django env
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=backend.settings \
    PORT_BACKEND=8000

WORKDIR /app

# 1️⃣ Install Python packages
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2️⃣ Copy Django code
COPY backend/ ./

# 3️⃣ Copy the static-exported frontend into Django’s static folder
#    (Assumes your STATIC_ROOT in settings.py points to os.path.join(BASE_DIR, 'static'))
COPY --from=frontend-builder /app/asr-frontend/out/ ./static/

# Expose Django port
EXPOSE ${PORT_BACKEND}

# 4️⃣ Run Gunicorn; WhiteNoise will handle serving /static/
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
