# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_HOME=/app \
    PORT=8000 \
    ENV=container

# Nie-root user dla bezpieczeństwa
RUN useradd -u 10001 -m appuser

WORKDIR ${APP_HOME}

# Zależności
COPY app/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Kod aplikacji
COPY app ./app

# Użyj stałej wartości (zmienne nie są niezawodnie rozwijane w EXPOSE)
EXPOSE 8000

# Healthcheck bez here-doc; prosty one-liner w Pythonie
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD python -c "import os,urllib.request,sys;url=f'http://127.0.0.1:{os.getenv(\"PORT\",\"8000\")}/';r=urllib.request.urlopen(url,timeout=2);sys.exit(0 if r.status==200 else 1)"

# Gunicorn: 1 worker (spójne /metrics), wielowątkowo na I/O
USER appuser
CMD ["gunicorn","--chdir","/app/app","-b","0.0.0.0:8000","--workers","1","--threads","8","--timeout","0","app:app"]
