#!/bin/bash
# Set up Cloud Scheduler to run scrapers automatically
# This creates schedulers that run each controller every minute with offsets

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "⏰ Setting up Cloud Scheduler for Scrapers"
echo "==========================================="
echo ""
echo "This will create schedulers that run each controller every minute"
echo "with 12-second offsets (Controller 1 at :00, Controller 2 at :12, etc.)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

# Offsets in seconds (for staggered execution)
OFFSETS=(0 12 24 36 48)

for i in {1..5}; do
  JOB_NAME="frontline-scraper-controller-${i}"
  SCHEDULER_NAME="frontline-scraper-controller-${i}-schedule"
  CONTROLLER_ID="controller_${i}"
  OFFSET=${OFFSETS[$((i-1))]}
  
  echo ""
  echo "Creating scheduler for $JOB_NAME (offset: ${OFFSET}s)..."
  
  # Cloud Scheduler minimum is 1 minute, so we schedule every minute
  # The scraper code handles the offset internally
  SCHEDULE="* * * * *"  # Every minute
  
  # URI to trigger the Cloud Run Job
  URI="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${JOB_NAME}:run"
  
  # Check if scheduler already exists
  if gcloud scheduler jobs describe "$SCHEDULER_NAME" \
      --location="$REGION" \
      --project="$PROJECT_ID" &>/dev/null; then
    echo "  ⚠️  Scheduler already exists, updating..."
    gcloud scheduler jobs update http "$SCHEDULER_NAME" \
      --location="$REGION" \
      --schedule="$SCHEDULE" \
      --uri="$URI" \
      --http-method POST \
      --oauth-service-account-email "$SERVICE_ACCOUNT" \
      --time-zone="America/Denver" \
      --project="$PROJECT_ID"
    echo "  ✅ Updated"
  else
    echo "  Creating new scheduler..."
    gcloud scheduler jobs create http "$SCHEDULER_NAME" \
      --location="$REGION" \
      --schedule="$SCHEDULE" \
      --uri="$URI" \
      --http-method POST \
      --oauth-service-account-email "$SERVICE_ACCOUNT" \
      --time-zone="America/Denver" \
      --project="$PROJECT_ID"
    echo "  ✅ Created"
  fi
done

echo ""
echo "✅ All schedulers created!"
echo ""
echo "Current Schedule:"
echo "  - Each controller runs every 1 minute"
echo "  - Controllers are offset by 12 seconds each"
echo "  - Combined effect: ~12 second intervals between scrapes"
echo ""
echo "To control schedulers:"
echo "  ./control-scrapers.sh status  # Check status"
echo "  ./control-scrapers.sh stop    # Pause all"
echo "  ./control-scrapers.sh start   # Resume all"
echo ""
echo "To change schedule frequency, edit the schedulers in Cloud Console:"
echo "  https://console.cloud.google.com/cloudscheduler?project=$PROJECT_ID"

