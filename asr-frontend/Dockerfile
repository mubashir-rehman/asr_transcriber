# ----------- Build frontend -----------
    FROM node:20 AS frontend-build

    WORKDIR /app/asr-frontend
    COPY asr-frontend/package.json asr-frontend/package-lock.json* ./
    RUN npm install
    COPY asr-frontend/ ./
    RUN npm run build
    
    # ----------- Build backend -----------
    FROM python:3.11-slim AS backend-build
    
    ENV PYTHONDONTWRITEBYTECODE 1
    ENV PYTHONUNBUFFERED 1
    
    WORKDIR /app
    
    # Install system dependencies (add more as needed)
    RUN apt-get update && apt-get install -y \
        build-essential \
        ffmpeg \
        libpq-dev \
        && rm -rf /var/lib/apt/lists/*
    
    # Copy backend code
    COPY backend/ ./backend/
    COPY backend/requirements.txt ./backend/requirements.txt
    
    # Install Python dependencies
    RUN pip install --upgrade pip
    RUN pip install -r backend/requirements.txt
    
    # Copy frontend build to backend staticfiles (optional, if you want Django to serve frontend)
    COPY --from=frontend-build /app/asr-frontend/.next /app/backend/static/.next
    COPY --from=frontend-build /app/asr-frontend/public /app/backend/static/public
    
    # ----------- Final image -----------
    FROM python:3.11-slim
    
    WORKDIR /app
    
    # Install system dependencies
    RUN apt-get update && apt-get install -y \
        ffmpeg \
        libpq-dev \
        && rm -rf /var/lib/apt/lists/*
    
    # Copy backend and installed packages
    COPY --from=backend-build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
    COPY --from=backend-build /app/backend /app/backend
    COPY --from=backend-build /app/backend/requirements.txt /app/backend/requirements.txt
    
    # Copy frontend build (for static serving, optional)
    COPY --from=frontend-build /app/asr-frontend/.next /app/backend/static/.next
    COPY --from=frontend-build /app/asr-frontend/public /app/backend/static/public
    
    # Set environment variables
    ENV DJANGO_SETTINGS_MODULE=backend.settings
    ENV PYTHONUNBUFFERED=1
    
    # Collect static files (if needed)
    RUN pip install --upgrade pip && pip install gunicorn
    RUN python backend/manage.py collectstatic --noinput
    
    # Expose ports (8000 for Django, 3000 for Next.js if needed)
    EXPOSE 8000
    
    # Start Django backend with Gunicorn
    CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:8000"]