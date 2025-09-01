# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_HOME=/app \
    PORT=8000 \
    ENV=container

RUN useradd -u 10001 -m appuser

WORKDIR ${APP_HOME}
COPY app/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY app ./app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD python -c "import os,urllib.request,sys;url=f'http://127.0.0.1:{os.getenv(\"PORT\",\"8000\")}/';r=urllib.request.urlopen(url,timeout=2);sys.exit(0 if r.status==200 else 1)"
USER appuser
CMD ["gunicorn","--chdir","/app/app","-b","0.0.0.0:8000","--workers","1","--threads","8","--timeout","0","app:app"]
