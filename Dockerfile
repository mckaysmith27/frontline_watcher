FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements_raw.txt /app/
RUN pip install --no-cache-dir -r requirements_raw.txt

# Install Playwright browsers (required for scraping)
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy application code
COPY frontline_watcher_refactored.py /app/frontline_watcher_refactored.py

ENV PYTHONUNBUFFERED=1

# Dockerfile for containerized deployments (EC2 or other container platforms)
# Long-running process (no HTTP server needed)
CMD ["python", "frontline_watcher_refactored.py"]

