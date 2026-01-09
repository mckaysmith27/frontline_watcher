#!/bin/bash

# View EC2 scraper logs
# Usage: ./view-ec2-logs.sh [controller-number] [follow]
# Examples:
#   ./view-ec2-logs.sh 1        # View last 50 lines from controller 1
#   ./view-ec2-logs.sh 1 follow # Follow logs in real-time
#   ./view-ec2-logs.sh          # View status of all controllers

EC2_HOST="${EC2_HOST:-sub67-watcher}"
CONTROLLER="${1:-all}"
FOLLOW="${2}"

if [ "$CONTROLLER" = "all" ]; then
    echo "📊 EC2 Scraper Status"
    echo "===================="
    echo ""
    ssh "$EC2_HOST" 'for i in {1..2}; do
        STATUS=$(sudo systemctl is-active frontline-watcher-controller_${i} 2>/dev/null || echo "inactive")
        echo "Controller $i: $STATUS"
    done'
    echo ""
    echo "To view logs: ./view-ec2-logs.sh 1"
    echo "To follow logs: ./view-ec2-logs.sh 1 follow"
    exit 0
fi

if [ "$FOLLOW" = "follow" ]; then
    echo "📝 Following logs for Controller $CONTROLLER (Ctrl+C to exit)..."
    echo "================================================================"
    ssh "$EC2_HOST" "sudo journalctl -u frontline-watcher-controller_${CONTROLLER} -f"
else
    echo "📝 Recent logs for Controller $CONTROLLER"
    echo "=========================================="
    echo ""
    
    # Try log file first, then journalctl
    ssh "$EC2_HOST" "tail -50 /var/log/frontline-watcher/controller_${CONTROLLER}.log 2>/dev/null || sudo journalctl -u frontline-watcher-controller_${CONTROLLER} -n 50 --no-pager"
    
    echo ""
    echo "To follow logs in real-time: ./view-ec2-logs.sh $CONTROLLER follow"
fi
