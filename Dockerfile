FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy

WORKDIR /app
COPY frontline_watcher.py /app/frontline_watcher.py

# Install ONLY the python package (no browsers). Keep it lean.
RUN python -m pip install --no-cache-dir playwright==1.45.0

ENV PYTHONUNBUFFERED=1
CMD ["python", "frontline_watcher.py"]
