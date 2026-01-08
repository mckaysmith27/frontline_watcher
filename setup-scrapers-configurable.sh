#!/bin/bash
# Configurable Scraper Setup
# Reads from scraper-config.json to set up the exact number of scrapers you want

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper:latest"

# Check if config file exists
if [ ! -f "scraper-config.json" ]; then
    echo "❌ Error: scraper-config.json not found"
    echo "   Create it first with your desired configuration"
    exit 1
fi

# Parse config using Python for better JSON parsing
NUM_SCRAPERS=$(python3 -c "import json; print(json.load(open('scraper-config.json'))['numScrapers'])" 2>/dev/null)
SCRAPE_INTERVAL=$(python3 -c "import json; print(json.load(open('scraper-config.json'))['scrapeIntervalSeconds'])" 2>/dev/null)
HOT_WINDOWS=$(python3 -c "import json; print(json.dumps(json.load(open('scraper-config.json'))['activeTimeWindows']))" 2>/dev/null || echo "[]")

if [ -z "$NUM_SCRAPERS" ] || [ -z "$SCRAPE_INTERVAL" ]; then
    echo "❌ Error: Invalid scraper-config.json"
    echo "   Required fields: numScrapers, scrapeIntervalSeconds"
    exit 1
fi

echo "🚀 Setting up Configurable Scrapers"
echo "===================================="
echo ""
echo "Configuration:"
echo "  Number of scrapers: $NUM_SCRAPERS"
echo "  Scrape interval: $SCRAPE_INTERVAL seconds per scraper"
echo "  Combined frequency: ~$((SCRAPE_INTERVAL / NUM_SCRAPERS)) seconds between scrapes"
echo ""

# Calculate offset per scraper
OFFSET_INTERVAL=$((SCRAPE_INTERVAL / NUM_SCRAPERS))

echo "📋 Creating Cloud Run Jobs..."
echo ""

# Create jobs for enabled controllers
for i in $(seq 1 $NUM_SCRAPERS); do
    JOB_NAME="frontline-scraper-controller-${i}"
    CONTROLLER_ID="controller_${i}"
    
    echo "Creating ${JOB_NAME} (${CONTROLLER_ID})..."
    
    # Build environment variables
    # Note: HOT_WINDOWS is handled by the scraper code reading from config, not env vars
    # The scraper code will read HOT_WINDOWS env var if set, but we'll let it use defaults
    ENV_VARS="CONTROLLER_ID=${CONTROLLER_ID},NUM_SCRAPERS=${NUM_SCRAPERS},SCRAPE_INTERVAL_SECONDS=${SCRAPE_INTERVAL}"
    
    # Determine secret names (controller 1 uses original secrets, others use controller-specific)
    if [ $i -eq 1 ]; then
        USERNAME_SECRET="frontline-username:latest"
        PASSWORD_SECRET="frontline-password:latest"
    else
        USERNAME_SECRET="frontline-username-controller-${i}:latest"
        PASSWORD_SECRET="frontline-password-controller-${i}:latest"
    fi
    
    SECRETS="FRONTLINE_USERNAME=${USERNAME_SECRET},FRONTLINE_PASSWORD=${PASSWORD_SECRET},FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"
    
    # Check if job already exists
    if gcloud run jobs describe "$JOB_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" &>/dev/null; then
        echo "  ⚠️  Job already exists, updating..."
        gcloud run jobs update ${JOB_NAME} \
            --image ${IMAGE_NAME} \
            --region ${REGION} \
            --memory 2Gi \
            --cpu 2 \
            --max-retries 3 \
            --task-timeout 3600 \
            --set-env-vars="${ENV_VARS}" \
            --set-secrets="${SECRETS}" \
            --project ${PROJECT_ID}
    else
        echo "  Creating new job..."
        gcloud run jobs create ${JOB_NAME} \
            --image ${IMAGE_NAME} \
            --region ${REGION} \
            --memory 2Gi \
            --cpu 2 \
            --max-retries 3 \
            --task-timeout 3600 \
            --set-env-vars="${ENV_VARS}" \
            --set-secrets="${SECRETS}" \
            --project ${PROJECT_ID}
    fi
    
    echo "  ✅ ${JOB_NAME} ready"
done

echo ""
echo "✅ All Cloud Run Jobs created!"
echo ""
echo "Next: Set up Cloud Scheduler with:"
echo "  ./setup-scheduler-configurable.sh"

