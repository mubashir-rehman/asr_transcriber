# ────────────────────────────────────────────────────────────
# Stage: Build & run Django backend only (no Node/Next.js)
# ────────────────────────────────────────────────────────────
FROM python:3.9-slim-bullseye

# Don’t buffer Python stdout/stderr
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=backend.settings \
    PORT=8000

WORKDIR /app

# 1️⃣ Install system libs & git for pip installs from GitHub
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
 && rm -rf /var/lib/apt/lists/*

# 2️⃣ Copy & install Python deps (including openai-whisper from Git)
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 3️⃣ Copy Django code
COPY backend/ ./

# 4️⃣ (Optional) Collect static files if you’re using Django staticfiles
# RUN python manage.py collectstatic --noinput

# 5️⃣ Expose port 8000
EXPOSE ${PORT}

# 6️⃣ Launch Gunicorn
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
