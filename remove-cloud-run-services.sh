#!/bin/bash

# Remove all Cloud Run Jobs and Schedulers after EC2 migration
# This stops duplicate scraping and reduces costs

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"

echo "🗑️  Removing Cloud Run Services (EC2 Migration Cleanup)"
echo "========================================================"
echo ""

# Step 1: Pause/Delete Cloud Schedulers
echo "📅 Step 1: Removing Cloud Schedulers..."
echo ""

for i in {1..5}; do
    SCHEDULER_NAME="frontline-scraper-controller-${i}-schedule"
    
    if gcloud scheduler jobs describe "$SCHEDULER_NAME" --location=$REGION --project=$PROJECT_ID &>/dev/null; then
        echo "  Deleting scheduler: $SCHEDULER_NAME"
        gcloud scheduler jobs delete "$SCHEDULER_NAME" \
            --location=$REGION \
            --project=$PROJECT_ID \
            --quiet
        echo "  ✅ Deleted $SCHEDULER_NAME"
    else
        echo "  ⚠️  $SCHEDULER_NAME not found, skipping"
    fi
done

echo ""

# Step 2: Delete Cloud Run Jobs
echo "🚫 Step 2: Deleting Cloud Run Jobs..."
echo ""

for i in {1..5}; do
    JOB_NAME="frontline-scraper-controller-${i}"
    
    if gcloud run jobs describe "$JOB_NAME" --region=$REGION --project=$PROJECT_ID &>/dev/null; then
        echo "  Deleting job: $JOB_NAME"
        gcloud run jobs delete "$JOB_NAME" \
            --region=$REGION \
            --project=$PROJECT_ID \
            --quiet
        echo "  ✅ Deleted $JOB_NAME"
    else
        echo "  ⚠️  $JOB_NAME not found, skipping"
    fi
done

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 What was removed:"
echo "  ✅ Cloud Schedulers (stopped triggering Cloud Run Jobs)"
echo "  ✅ Cloud Run Jobs (no longer scraping - EC2 handles this now)"
echo ""
echo "📋 What remains (still needed):"
echo "  ✅ Cloud Functions (onJobEventCreated) - Processes job events, sends notifications"
echo ""
echo "💰 Cost Impact:"
echo "  - Cloud Run Jobs: ~$5-10/day → $0/day (SAVED)"
echo "  - Cloud Functions: ~$0.01/month (very cheap, only runs when job events created)"
echo ""
