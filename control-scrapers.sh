#!/bin/bash
# Control Cloud Run Scraper Jobs
# Usage: ./control-scrapers.sh [status|start|stop|pause|resume]

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"
CONTROLLERS=(1 2 3 4 5)

ACTION="${1:-status}"

case "$ACTION" in
  status)
    echo "📊 Current Scraper Status"
    echo "=========================="
    echo ""
    
    # Check Cloud Run Jobs
    echo "Cloud Run Jobs:"
    for i in "${CONTROLLERS[@]}"; do
      JOB_NAME="frontline-scraper-controller-${i}"
      STATUS=$(gcloud run jobs describe "$JOB_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(status.conditions[0].type)" 2>/dev/null || echo "NOT_FOUND")
      echo "  $JOB_NAME: $STATUS"
    done
    
    echo ""
    echo "Cloud Scheduler Jobs:"
    SCHEDULERS=$(gcloud scheduler jobs list \
      --location="$REGION" \
      --project="$PROJECT_ID" \
      --filter="name~frontline-scraper" \
      --format="value(name)" 2>/dev/null || echo "")
    
    if [ -z "$SCHEDULERS" ]; then
      echo "  ⚠️  No schedulers configured (jobs run manually only)"
      echo ""
      echo "Current Schedule: MANUAL ONLY"
      echo "  Jobs only run when you execute them manually"
      echo ""
      echo "To enable automatic scheduling, run:"
      echo "  ./setup-scheduler.sh"
    else
      echo "  Found schedulers:"
      for scheduler in $SCHEDULERS; do
        STATE=$(gcloud scheduler jobs describe "$scheduler" \
          --location="$REGION" \
          --project="$PROJECT_ID" \
          --format="value(state)" 2>/dev/null || echo "UNKNOWN")
        SCHEDULE=$(gcloud scheduler jobs describe "$scheduler" \
          --location="$REGION" \
          --project="$PROJECT_ID" \
          --format="value(schedule)" 2>/dev/null || echo "UNKNOWN")
        echo "    $scheduler: $STATE (schedule: $SCHEDULE)"
      done
    fi
    ;;
    
  start|resume)
    echo "▶️  Starting/Resuming Scraper Schedulers"
    echo "========================================"
    echo ""
    
    for i in "${CONTROLLERS[@]}"; do
      SCHEDULER_NAME="frontline-scraper-controller-${i}-schedule"
      echo "Resuming $SCHEDULER_NAME..."
      gcloud scheduler jobs resume "$SCHEDULER_NAME" \
        --location="$REGION" \
        --project="$PROJECT_ID" 2>/dev/null && echo "  ✅ Resumed" || echo "  ⚠️  Scheduler not found (may not be set up)"
    done
    
    echo ""
    echo "✅ All schedulers resumed"
    echo ""
    echo "To check status: ./control-scrapers.sh status"
    ;;
    
  stop|pause)
    echo "⏸️  Pausing Scraper Schedulers"
    echo "=============================="
    echo ""
    
    for i in "${CONTROLLERS[@]}"; do
      SCHEDULER_NAME="frontline-scraper-controller-${i}-schedule"
      echo "Pausing $SCHEDULER_NAME..."
      gcloud scheduler jobs pause "$SCHEDULER_NAME" \
        --location="$REGION" \
        --project="$PROJECT_ID" 2>/dev/null && echo "  ✅ Paused" || echo "  ⚠️  Scheduler not found (may not be set up)"
    done
    
    echo ""
    echo "✅ All schedulers paused"
    echo ""
    echo "Jobs will NOT run automatically until resumed"
    echo "To resume: ./control-scrapers.sh resume"
    ;;
    
  *)
    echo "Usage: $0 [status|start|stop|pause|resume]"
    echo ""
    echo "Commands:"
    echo "  status  - Show current status of scrapers and schedulers"
    echo "  start   - Resume automatic scheduling (start scrapers)"
    echo "  stop    - Pause automatic scheduling (stop scrapers)"
    echo "  pause   - Same as stop"
    echo "  resume  - Same as start"
    exit 1
    ;;
esac

