#!/bin/bash
# Quick status check for Cloud Run Jobs (faster than reading logs)

echo "📊 Recent Job Executions:"
gcloud run jobs executions list \
  --job=frontline-scraper-controller-1 \
  --region=us-central1 \
  --project=sub67-d4648 \
  --limit=3 \
  --format="table(name,status.conditions[0].type,status.conditions[0].status)" 2>&1

echo ""
echo "📋 Latest Logs (last 5 minutes, simplified):"
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=frontline-scraper-controller-1 AND timestamp>=\"$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)\"" \
  --project=sub67-d4648 \
  --limit=5 \
  --format="value(textPayload)" 2>&1 | grep -E "Monitoring|auth|publish|ERROR" | tail -5

