# Use a slim Python image
FROM python:3.9-slim-bullseye

# Don’t buffer Python stdout/stderr
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=backend.settings \
    PORT=8000

WORKDIR /app

# 1️⃣ Install system libs needed by your Python dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# 2️⃣ Install Python deps
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3️⃣ Copy your Django code
COPY backend/ .

# 4️⃣ (Optional) Collect static files if you’re using Django staticfiles
# RUN python manage.py collectstatic --noinput

# 5️⃣ Expose the port your app will run on
EXPOSE ${PORT}

# 6️⃣ Launch Gunicorn
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
