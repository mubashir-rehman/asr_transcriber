# Stage 1: Build the Next.js frontend
FROM node:18-bullseye-slim AS frontend-builder

WORKDIR /app/asr-frontend
COPY asr-frontend/package.json asr-frontend/package-lock.json ./
RUN npm ci
COPY asr-frontend/ ./
RUN npm run build

# Stage 2: Build Python backend + bundle frontend
FROM python:3.9-slim-bullseye

# Install runtime deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      nodejs \
      npm \
      git \
 && rm -rf /var/lib/apt/lists/*

# Django env
ENV PYTHONUNBUFFERED=1 \
    PORT_BACKEND=8000 \
    PORT_FRONTEND=3000 \
    DJANGO_SETTINGS_MODULE=backend.settings

WORKDIR /app

# Install Python deps
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ ./

# Copy built frontend from stage 1
COPY --from=frontend-builder /app/asr-frontend/.next ./asr-frontend/.next
COPY --from=frontend-builder /app/asr-frontend/public ./asr-frontend/public
COPY --from=frontend-builder /app/asr-frontend/node_modules ./asr-frontend/node_modules
COPY --from=frontend-builder /app/asr-frontend/package.json ./asr-frontend/package.json

# Expose ports
EXPOSE ${PORT_BACKEND}
EXPOSE ${PORT_FRONTEND}

# Launch both Gunicorn (Django) and Next.js
CMD bash -lc "\
  gunicorn backend.wsgi:application --bind 0.0.0.0:${PORT_BACKEND} --workers=3 & \
  cd asr-frontend && npm run start -- -p ${PORT_FRONTEND} \
"
