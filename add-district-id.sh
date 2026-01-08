#!/bin/bash
# Quick script to add DISTRICT_ID secret
# Run: ./add-district-id.sh

read -p "Enter your DISTRICT_ID: " DISTRICT_ID

if [ -z "$DISTRICT_ID" ]; then
    echo "❌ DISTRICT_ID cannot be empty"
    exit 1
fi

echo -n "${DISTRICT_ID}" | gcloud secrets create district-id --data-file=- --project sub67-d4648

PROJECT_NUMBER=$(gcloud projects describe sub67-d4648 --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding district-id \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor" \
    --project sub67-d4648 \
    --quiet

echo "✅ Created district-id secret"
echo "🎉 All secrets are now configured!"
echo ""
echo "You can now run: ./deploy-all.sh"

