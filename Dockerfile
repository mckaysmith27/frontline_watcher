FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements_raw.txt /app/
RUN pip install --no-cache-dir -r requirements_raw.txt

# Install Playwright browsers (required for scraping)
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy application code
COPY frontline_watcher_refactored.py /app/frontline_watcher.py

ENV PYTHONUNBUFFERED=1

# Cloud Run expects the container to listen on PORT, but we don't need HTTP
# We'll use a long-running process instead
CMD ["python", "frontline_watcher.py"]

