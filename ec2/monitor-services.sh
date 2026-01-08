#!/bin/bash

# Monitor all Frontline Watcher services on EC2
# Usage: ./monitor-services.sh [status|logs|restart|stop|start]

ACTION="${1:-status}"
NUM_CONTROLLERS="${2:-5}"

case "$ACTION" in
    status)
        echo "📊 Service Status:"
        echo "=================="
        for i in $(seq 1 $NUM_CONTROLLERS); do
            SERVICE="frontline-watcher-controller_${i}"
            if systemctl is-active --quiet $SERVICE; then
                STATUS="✅ RUNNING"
            else
                STATUS="❌ STOPPED"
            fi
            echo "  $SERVICE: $STATUS"
        done
        ;;
    logs)
        CONTROLLER="${2:-1}"
        SERVICE="frontline-watcher-controller_${CONTROLLER}"
        echo "📝 Logs for $SERVICE (Ctrl+C to exit):"
        echo "======================================"
        sudo journalctl -u $SERVICE -f
        ;;
    restart)
        echo "🔄 Restarting all services..."
        for i in $(seq 1 $NUM_CONTROLLERS); do
            SERVICE="frontline-watcher-controller_${i}"
            echo "  Restarting $SERVICE..."
            sudo systemctl restart $SERVICE
        done
        echo "✅ All services restarted"
        ;;
    stop)
        echo "🛑 Stopping all services..."
        for i in $(seq 1 $NUM_CONTROLLERS); do
            SERVICE="frontline-watcher-controller_${i}"
            echo "  Stopping $SERVICE..."
            sudo systemctl stop $SERVICE
        done
        echo "✅ All services stopped"
        ;;
    start)
        echo "▶️  Starting all services..."
        for i in $(seq 1 $NUM_CONTROLLERS); do
            SERVICE="frontline-watcher-controller_${i}"
            echo "  Starting $SERVICE..."
            sudo systemctl start $SERVICE
        done
        echo "✅ All services started"
        ;;
    *)
        echo "Usage: $0 [status|logs|restart|stop|start] [controller-number]"
        echo ""
        echo "Examples:"
        echo "  $0 status              # Show status of all services"
        echo "  $0 logs 1             # Show logs for controller_1"
        echo "  $0 restart            # Restart all services"
        echo "  $0 stop               # Stop all services"
        echo "  $0 start              # Start all services"
        exit 1
        ;;
esac
