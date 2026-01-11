#!/bin/bash
# Check recent logs from controller_1 on EC2
# Usage: ./check-ec2-logs.sh [ec2-host] [lines]

EC2_HOST="${1:-ubuntu@18.188.47.102}"
LINES="${2:-50}"

echo "📋 Recent Controller 1 Logs (last $LINES lines)"
echo "================================================"
echo ""

ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem "$EC2_HOST" "sudo journalctl -u frontline-watcher-controller_1 -n $LINES --no-pager"

echo ""
echo ""
echo "💡 What to look for:"
echo "  ✅ '[available_jobs baseline]:' - Shows what jobs were found at startup"
echo "  ✅ '[monitor] Found X job(s) on page' - Jobs detected during monitoring"
echo "  ✅ '[publish] ✅ Published and notified for job XXX' - New jobs published"
echo "  ⚠️  If baseline shows 'NO_AVAILABLE_JOBS' - No jobs found (this is normal)"
echo "  ⚠️  If you see '(sleeping X.XXs)' - Scraper is running and waiting"
