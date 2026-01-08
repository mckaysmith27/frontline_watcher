#!/bin/bash

# Control individual Frontline Watcher controllers on EC2
# Usage: ./control-controllers.sh [start|stop|restart|status] [controller_number|all]

set -e

ACTION="${1:-status}"
CONTROLLER="${2:-all}"
EC2_HOST="sub67-watcher"

if [ "$ACTION" != "start" ] && [ "$ACTION" != "stop" ] && [ "$ACTION" != "restart" ] && [ "$ACTION" != "status" ]; then
    echo "Usage: $0 [start|stop|restart|status] [controller_number|all]"
    echo ""
    echo "Examples:"
    echo "  $0 stop 2          # Stop controller 2 only"
    echo "  $0 start 1         # Start controller 1 only"
    echo "  $0 restart all     # Restart all controllers"
    echo "  $0 status          # Show status of all controllers"
    exit 1
fi

if [ "$CONTROLLER" = "all" ]; then
    CONTROLLERS=(1 2)
else
    CONTROLLERS=("$CONTROLLER")
fi

echo "🔧 Frontline Watcher Controller Control"
echo "========================================"
echo "Action: $ACTION"
echo "Controllers: ${CONTROLLERS[*]}"
echo ""

for i in "${CONTROLLERS[@]}"; do
    SERVICE_NAME="frontline-watcher-controller_${i}"
    
    case "$ACTION" in
        start)
            echo "▶️  Starting $SERVICE_NAME..."
            ssh "$EC2_HOST" "sudo systemctl start $SERVICE_NAME"
            sleep 2
            STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
            if [ "$STATUS" = "active" ]; then
                echo "   ✅ $SERVICE_NAME started"
            else
                echo "   ❌ $SERVICE_NAME failed to start"
            fi
            ;;
        stop)
            echo "⏹️  Stopping $SERVICE_NAME..."
            ssh "$EC2_HOST" "sudo systemctl stop $SERVICE_NAME"
            sleep 1
            STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
            if [ "$STATUS" = "inactive" ]; then
                echo "   ✅ $SERVICE_NAME stopped"
            else
                echo "   ⚠️  $SERVICE_NAME may still be running"
            fi
            ;;
        restart)
            echo "🔄 Restarting $SERVICE_NAME..."
            ssh "$EC2_HOST" "sudo systemctl restart $SERVICE_NAME"
            sleep 2
            STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
            if [ "$STATUS" = "active" ]; then
                echo "   ✅ $SERVICE_NAME restarted"
            else
                echo "   ❌ $SERVICE_NAME failed to restart"
            fi
            ;;
        status)
            STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
            if [ "$STATUS" = "active" ]; then
                echo "✅ Controller $i: RUNNING"
            else
                echo "❌ Controller $i: STOPPED"
            fi
            ;;
    esac
done

echo ""
if [ "$ACTION" = "status" ]; then
    echo "📋 View logs:"
    echo "  ./view-ec2-logs.sh [controller_number] [follow]"
fi
