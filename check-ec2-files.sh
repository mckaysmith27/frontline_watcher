#!/bin/bash
# Quick script to check what files exist on EC2
# Usage: ./check-ec2-files.sh [ec2-host]

EC2_HOST="${1:-ubuntu@18.188.47.102}"
APP_DIR="/opt/frontline-watcher"

echo "🔍 Checking EC2 Files"
echo "===================="
echo "Host: $EC2_HOST"
echo "App Directory: $APP_DIR"
echo ""

ssh "$EC2_HOST" << EOF
    echo "📁 Application Directory:"
    if [ -d "$APP_DIR" ]; then
        echo "✅ Directory exists: $APP_DIR"
        echo ""
        echo "📋 Files in $APP_DIR:"
        ls -la "$APP_DIR" 2>/dev/null || echo "  (cannot list - may need sudo)"
        echo ""
        echo "📄 Python files:"
        ls -la "$APP_DIR"/*.py 2>/dev/null || echo "  No .py files found"
        echo ""
        echo "📝 .env files:"
        ls -la "$APP_DIR"/.env* 2>/dev/null || echo "  No .env files found"
        echo ""
        echo "📦 Virtual environment:"
        if [ -d "$APP_DIR/venv" ]; then
            echo "✅ venv exists"
        else
            echo "❌ venv not found"
        fi
        echo ""
        echo "🔧 Systemd services:"
        sudo systemctl list-units --type=service | grep frontline-watcher || echo "  No frontline-watcher services found"
    else
        echo "❌ Directory does not exist: $APP_DIR"
        echo ""
        echo "Checking if it exists elsewhere:"
        sudo find /opt -name "*frontline*" -type d 2>/dev/null | head -10
    fi
EOF
