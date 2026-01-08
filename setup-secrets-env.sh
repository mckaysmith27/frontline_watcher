#!/bin/bash
# Setup secrets from environment variables (non-interactive)
# Usage: 
#   export FRONTLINE_USERNAME="your_username"
#   export FRONTLINE_PASSWORD="your_password"
#   export FIREBASE_CREDENTIALS_PATH="/path/to/service-account.json"
#   export DISTRICT_ID="your_district_id"
#   export FIREBASE_PROJECT_ID="sub67-d4648"
#   ./setup-secrets-env.sh

set -e

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "🔐 Setting up secrets for Frontline Scraper (from environment variables)"
echo "Project: ${PROJECT_ID}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo ""

# Check required environment variables
if [ -z "$FRONTLINE_USERNAME" ] || [ -z "$FRONTLINE_PASSWORD" ] || [ -z "$FIREBASE_CREDENTIALS_PATH" ] || [ -z "$DISTRICT_ID" ]; then
    echo "❌ Missing required environment variables:"
    echo "   Required: FRONTLINE_USERNAME, FRONTLINE_PASSWORD, FIREBASE_CREDENTIALS_PATH, DISTRICT_ID"
    echo "   Optional: FIREBASE_PROJECT_ID (defaults to ${PROJECT_ID})"
    echo ""
    echo "Set them like this:"
    echo "   export FRONTLINE_USERNAME='your_username'"
    echo "   export FRONTLINE_PASSWORD='your_password'"
    echo "   export FIREBASE_CREDENTIALS_PATH='/path/to/service-account.json'"
    echo "   export DISTRICT_ID='your_district_id'"
    echo "   export FIREBASE_PROJECT_ID='sub67-d4648'"
    exit 1
fi

FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-${PROJECT_ID}}

# Check if Firebase credentials file exists
if [ ! -f "$FIREBASE_CREDENTIALS_PATH" ]; then
    echo "❌ Firebase credentials file not found: $FIREBASE_CREDENTIALS_PATH"
    exit 1
fi

# Check if secrets already exist
check_secret() {
    if gcloud secrets describe $1 --project ${PROJECT_ID} &>/dev/null; then
        echo "⚠️  Secret $1 already exists. Updating..."
        return 1
    fi
    return 0
}

# Create or update secrets
echo "Creating/updating secrets..."

if check_secret "frontline-username"; then
    echo -n "${FRONTLINE_USERNAME}" | gcloud secrets create frontline-username \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Created frontline-username"
else
    echo -n "${FRONTLINE_USERNAME}" | gcloud secrets versions add frontline-username \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Updated frontline-username"
fi

if check_secret "frontline-password"; then
    echo -n "${FRONTLINE_PASSWORD}" | gcloud secrets create frontline-password \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Created frontline-password"
else
    echo -n "${FRONTLINE_PASSWORD}" | gcloud secrets versions add frontline-password \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Updated frontline-password"
fi

if check_secret "firebase-credentials"; then
    gcloud secrets create firebase-credentials \
        --data-file="${FIREBASE_CREDENTIALS_PATH}" \
        --project ${PROJECT_ID}
    echo "✅ Created firebase-credentials"
else
    gcloud secrets versions add firebase-credentials \
        --data-file="${FIREBASE_CREDENTIALS_PATH}" \
        --project ${PROJECT_ID}
    echo "✅ Updated firebase-credentials"
fi

if check_secret "district-id"; then
    echo -n "${DISTRICT_ID}" | gcloud secrets create district-id \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Created district-id"
else
    echo -n "${DISTRICT_ID}" | gcloud secrets versions add district-id \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Updated district-id"
fi

if check_secret "firebase-project-id"; then
    echo -n "${FIREBASE_PROJECT_ID}" | gcloud secrets create firebase-project-id \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Created firebase-project-id"
else
    echo -n "${FIREBASE_PROJECT_ID}" | gcloud secrets versions add firebase-project-id \
        --data-file=- \
        --project ${PROJECT_ID}
    echo "✅ Updated firebase-project-id"
fi

# Grant Cloud Functions/EC2 access to secrets
echo ""
echo "🔑 Granting service account access to secrets (for Cloud Functions and EC2)..."

for SECRET in frontline-username frontline-password firebase-credentials district-id firebase-project-id; do
    gcloud secrets add-iam-policy-binding ${SECRET} \
        --member="serviceAccount:${SERVICE_ACCOUNT}" \
        --role="roles/secretmanager.secretAccessor" \
        --project ${PROJECT_ID} \
        --quiet
    echo "✅ Granted access to ${SECRET}"
done

echo ""
echo "🎉 All secrets configured!"
echo ""
echo "Note: Scrapers now run on EC2. To update EC2 with new credentials:"
echo "  ssh sub67-watcher 'cd /opt/frontline-watcher && sudo systemctl restart frontline-watcher-controller_*'"

