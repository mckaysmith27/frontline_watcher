#!/bin/bash
# Set up credentials for a specific controller
# Usage: ./setup-controller-credentials.sh <controller_number> <username> <password>

set -e

PROJECT_ID="sub67-d4648"
CONTROLLER_NUM="${1}"
USERNAME="${2}"
PASSWORD="${3}"

if [ -z "$CONTROLLER_NUM" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <controller_number> <username> <password>"
    echo ""
    echo "Example:"
    echo "  $0 2 myusername mypassword"
    exit 1
fi

SECRET_USERNAME="frontline-username-controller-${CONTROLLER_NUM}"
SECRET_PASSWORD="frontline-password-controller-${CONTROLLER_NUM}"

echo "🔐 Setting up credentials for Controller ${CONTROLLER_NUM}"
echo "=========================================================="
echo ""

# Create or update username secret
if gcloud secrets describe "$SECRET_USERNAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "Updating username secret: $SECRET_USERNAME"
    echo -n "$USERNAME" | gcloud secrets versions add "$SECRET_USERNAME" \
        --data-file=- \
        --project="$PROJECT_ID"
else
    echo "Creating username secret: $SECRET_USERNAME"
    echo -n "$USERNAME" | gcloud secrets create "$SECRET_USERNAME" \
        --data-file=- \
        --project="$PROJECT_ID"
fi

# Create or update password secret
if gcloud secrets describe "$SECRET_PASSWORD" --project="$PROJECT_ID" &>/dev/null; then
    echo "Updating password secret: $SECRET_PASSWORD"
    echo -n "$PASSWORD" | gcloud secrets versions add "$SECRET_PASSWORD" \
        --data-file=- \
        --project="$PROJECT_ID"
else
    echo "Creating password secret: $SECRET_PASSWORD"
    echo -n "$PASSWORD" | gcloud secrets create "$SECRET_PASSWORD" \
        --data-file=- \
        --project="$PROJECT_ID"
fi

# Grant Cloud Run access
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo ""
echo "Granting Cloud Run access to secrets..."
gcloud secrets add-iam-policy-binding "$SECRET_USERNAME" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID" 2>/dev/null || echo "  Access already granted for username"

gcloud secrets add-iam-policy-binding "$SECRET_PASSWORD" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID" 2>/dev/null || echo "  Access already granted for password"

echo ""
echo "✅ Credentials set up for Controller ${CONTROLLER_NUM}!"
echo ""
echo "Next: Update the Cloud Run Job to use these secrets:"
echo "  ./setup-scrapers-configurable.sh"

