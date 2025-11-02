FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy

WORKDIR /app

COPY frontline_watcher.py /app/frontline_watcher.py

RUN pip install --no-cache-dir playwright==1.45.0 requests

ENV PYTHONUNBUFFERED=1

CMD ["python", "frontline_watcher.py"]
