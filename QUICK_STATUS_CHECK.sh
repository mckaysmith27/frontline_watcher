#!/bin/bash
# Quick status check for EC2 scrapers

EC2_HOST="${1:-sub67-watcher}"

echo "📊 EC2 Scraper Status"
echo "===================="
echo ""

if ! ssh -o ConnectTimeout=5 "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to EC2: $EC2_HOST"
    echo "   Make sure SSH is configured correctly"
    exit 1
fi

echo "Controller Status:"
ssh "$EC2_HOST" 'for i in {1..2}; do
    STATUS=$(sudo systemctl is-active frontline-watcher-controller_${i} 2>/dev/null || echo "inactive")
    echo "  Controller $i: $STATUS"
done'

echo ""
echo "Recent Logs (Controller 1, last 10 lines):"
ssh "$EC2_HOST" 'sudo journalctl -u frontline-watcher-controller_1 -n 10 --no-pager | tail -10' 2>/dev/null || echo "  No logs available"

echo ""
echo "📋 To view full logs:"
echo "  ssh $EC2_HOST 'sudo journalctl -u frontline-watcher-controller_1 -f'"

