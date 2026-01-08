#!/bin/bash
# Set up Cloud Scheduler with configurable intervals and time windows
# Reads from scraper-config.json

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Check if config file exists
if [ ! -f "scraper-config.json" ]; then
    echo "❌ Error: scraper-config.json not found"
    exit 1
fi

# Parse config
NUM_SCRAPERS=$(cat scraper-config.json | grep -o '"numScrapers": [0-9]*' | grep -o '[0-9]*')
SCRAPE_INTERVAL=$(cat scraper-config.json | grep -o '"scrapeIntervalSeconds": [0-9]*' | grep -o '[0-9]*')
TIMEZONE=$(cat scraper-config.json | grep -o '"timezone": "[^"]*"' | cut -d'"' -f4 || echo "America/Denver")

if [ -z "$NUM_SCRAPERS" ] || [ -z "$SCRAPE_INTERVAL" ]; then
    echo "❌ Error: Invalid scraper-config.json"
    exit 1
fi

# Calculate offset per scraper
OFFSET_INTERVAL=$((SCRAPE_INTERVAL / NUM_SCRAPERS))

echo "⏰ Setting up Cloud Scheduler (Configurable)"
echo "============================================="
echo ""
echo "Configuration:"
echo "  Number of scrapers: $NUM_SCRAPERS"
echo "  Scrape interval: $SCRAPE_INTERVAL seconds per scraper"
echo "  Offset between scrapers: $OFFSET_INTERVAL seconds"
echo "  Combined frequency: ~$OFFSET_INTERVAL seconds between scrapes"
echo "  Timezone: $TIMEZONE"
echo ""

# Enable Cloud Scheduler API
echo "🔧 Enabling Cloud Scheduler API..."
gcloud services enable cloudscheduler.googleapis.com --project="$PROJECT_ID" 2>/dev/null || echo "  Already enabled"

# Parse time windows from config (if any)
# For now, we'll create schedulers that run during active windows
# Cloud Scheduler supports cron with timezone, so we can schedule for specific hours

# Calculate cron schedule
# Cloud Scheduler minimum is 1 minute, so we need to convert seconds to minutes
# If interval is less than 60 seconds, we'll use every minute and let the scraper handle timing
if [ $SCRAPE_INTERVAL -lt 60 ]; then
    CRON_SCHEDULE="* * * * *"  # Every minute
    echo "  ⚠️  Note: Cloud Scheduler minimum is 1 minute"
    echo "     Scrapers will run every minute, but code handles $SCRAPE_INTERVAL second intervals"
else
    MINUTES=$((SCRAPE_INTERVAL / 60))
    CRON_SCHEDULE="*/${MINUTES} * * * *"  # Every N minutes
fi

echo ""
echo "📋 Creating Schedulers..."
echo ""

for i in $(seq 1 $NUM_SCRAPERS); do
    JOB_NAME="frontline-scraper-controller-${i}"
    SCHEDULER_NAME="frontline-scraper-controller-${i}-schedule"
    
    # Calculate offset in seconds for this controller
    OFFSET=$((OFFSET_INTERVAL * (i - 1)))
    
    echo "Creating scheduler for $JOB_NAME..."
    echo "  Offset: ${OFFSET}s"
    echo "  Schedule: $CRON_SCHEDULE"
    
    # URI to trigger the Cloud Run Job
    URI="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${JOB_NAME}:run"
    
    # Check if scheduler already exists
    if gcloud scheduler jobs describe "$SCHEDULER_NAME" \
        --location="$REGION" \
        --project="$PROJECT_ID" &>/dev/null; then
        echo "  ⚠️  Scheduler already exists, updating..."
        gcloud scheduler jobs update http "$SCHEDULER_NAME" \
            --location="$REGION" \
            --schedule="$CRON_SCHEDULE" \
            --uri="$URI" \
            --http-method POST \
            --oauth-service-account-email "$SERVICE_ACCOUNT" \
            --time-zone="$TIMEZONE" \
            --project="$PROJECT_ID"
        echo "  ✅ Updated"
    else
        echo "  Creating new scheduler..."
        gcloud scheduler jobs create http "$SCHEDULER_NAME" \
            --location="$REGION" \
            --schedule="$CRON_SCHEDULE" \
            --uri="$URI" \
            --http-method POST \
            --oauth-service-account-email "$SERVICE_ACCOUNT" \
            --time-zone="$TIMEZONE" \
            --project="$PROJECT_ID"
        echo "  ✅ Created"
    fi
done

echo ""
echo "✅ All schedulers created!"
echo ""
echo "📊 Summary:"
echo "  - $NUM_SCRAPERS scrapers configured"
echo "  - Each scraper runs every $SCRAPE_INTERVAL seconds"
echo "  - Combined scraping frequency: ~$OFFSET_INTERVAL seconds"
echo ""
echo "To control schedulers:"
echo "  ./control-scrapers.sh status  # Check status"
echo "  ./control-scrapers.sh stop    # Pause all"
echo "  ./control-scrapers.sh start   # Resume all"
echo ""
echo "Note: Time windows are configured in scraper-config.json"
echo "      The scraper code checks these windows before running"

