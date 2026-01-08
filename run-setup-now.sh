#!/bin/bash
# Run complete setup - prompts for Controller 2 credentials

set -e

echo "🔐 Controller 2 Setup"
echo "======================"
echo ""
echo "Please provide Controller 2 credentials:"
echo ""

read -p "Username: " USERNAME2
read -sp "Password: " PASSWORD2
echo ""

if [ -z "$USERNAME2" ] || [ -z "$PASSWORD2" ]; then
    echo "❌ Error: Username and password are required"
    exit 1
fi

echo ""
echo "🚀 Starting complete setup..."
echo ""

# Run the complete setup script
./complete-setup-controller-2.sh "$USERNAME2" "$PASSWORD2"

