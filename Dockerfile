# Stage 1: Build the Next.js frontend
FROM node:18-bullseye-slim AS frontend-builder

WORKDIR /app/asr-frontend

# Install dependencies
COPY asr-frontend/package.json asr-frontend/package-lock.json ./
RUN npm ci

# Copy source & build
COPY asr-frontend/ ./
RUN npm run build

# Stage 2: Build the Python backend + bundle frontend
FROM python:3.9-slim-bullseye

# Install runtime deps: git (if you import any private git pkgs), node & npm to serve Next.js
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      nodejs \
      npm \
      git \
 && rm -rf /var/lib/apt/lists/*

# Set env vars for Django
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=backend.settings \
    PORT_BACKEND=8000 \
    PORT_FRONTEND=3000

WORKDIR /app

#
# 1) Install & copy the Django backend
#
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the backend
COPY backend/ ./

#
# 2) Copy the already-built frontend assets from stage 1
#
#    We bring over the Next.js build output & static files
COPY --from=frontend-builder /app/asr-frontend/.next ./asr-frontend/.next
COPY --from=frontend-builder /app/asr-frontend/public ./asr-frontend/public
COPY frontend-builder /app/asr-frontend/node_modules ./asr-frontend/node_modules
COPY frontend-builder /app/asr-frontend/package.json ./asr-frontend/

# Expose both ports
EXPOSE ${PORT_BACKEND}
EXPOSE ${PORT_FRONTEND}

# Root command: launch both Gunicorn & Next.js
# - Gunicorn serves Django on 0.0.0.0:8000
# - Next.js serves on 0.0.0.0:3000
CMD bash -lc "\
  gunicorn backend.wsgi:application --bind 0.0.0.0:${PORT_BACKEND} --workers=3 & \
  cd asr-frontend && npm run start -- -p ${PORT_FRONTEND} \
"
