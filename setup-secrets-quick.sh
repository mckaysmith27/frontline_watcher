#!/bin/bash
# Quick secrets setup - prompts for each value one at a time
# Run: ./setup-secrets-quick.sh

set -e

PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "🔐 Setting up secrets for Frontline Scraper"
echo "Project: ${PROJECT_ID}"
echo ""

# Get values
read -p "Enter FRONTLINE_USERNAME: " FRONTLINE_USERNAME
read -sp "Enter FRONTLINE_PASSWORD: " FRONTLINE_PASSWORD
echo ""
read -p "Enter path to Firebase service account JSON file: " FIREBASE_CREDENTIALS_PATH
read -p "Enter DISTRICT_ID: " DISTRICT_ID
read -p "Enter FIREBASE_PROJECT_ID (default: ${PROJECT_ID}): " FIREBASE_PROJECT_ID_INPUT
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID_INPUT:-${PROJECT_ID}}

# Validate Firebase credentials file
if [ ! -f "$FIREBASE_CREDENTIALS_PATH" ]; then
    echo "❌ Firebase credentials file not found: $FIREBASE_CREDENTIALS_PATH"
    exit 1
fi

echo ""
echo "Creating secrets..."

# Create secrets
echo -n "${FRONTLINE_USERNAME}" | gcloud secrets create frontline-username --data-file=- --project ${PROJECT_ID}
echo "✅ Created frontline-username"

echo -n "${FRONTLINE_PASSWORD}" | gcloud secrets create frontline-password --data-file=- --project ${PROJECT_ID}
echo "✅ Created frontline-password"

gcloud secrets create firebase-credentials --data-file="${FIREBASE_CREDENTIALS_PATH}" --project ${PROJECT_ID}
echo "✅ Created firebase-credentials"

echo -n "${DISTRICT_ID}" | gcloud secrets create district-id --data-file=- --project ${PROJECT_ID}
echo "✅ Created district-id"

echo -n "${FIREBASE_PROJECT_ID}" | gcloud secrets create firebase-project-id --data-file=- --project ${PROJECT_ID}
echo "✅ Created firebase-project-id"

# Grant access
echo ""
echo "Granting Cloud Run access..."
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
echo "Run ./deploy-all.sh to deploy"

