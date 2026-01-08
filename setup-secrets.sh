#!/bin/bash
# Setup Google Cloud Secret Manager secrets for Frontline Scraper
# Run this before deploying to Cloud Run

set -e

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "🔐 Setting up secrets for Frontline Scraper"
echo "Project: ${PROJECT_ID}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo ""

# Check if secrets already exist
check_secret() {
  if gcloud secrets describe $1 --project ${PROJECT_ID} &>/dev/null; then
    echo "⚠️  Secret $1 already exists. Skipping..."
    return 1
  fi
  return 0
}

# Create secrets (interactive prompts for sensitive data)
echo "Creating secrets (you'll be prompted for values)..."
echo ""

if check_secret "frontline-username"; then
  read -sp "Enter FRONTLINE_USERNAME: " USERNAME
  echo ""
  echo -n "${USERNAME}" | gcloud secrets create frontline-username \
    --data-file=- \
    --project ${PROJECT_ID}
  echo "✅ Created frontline-username"
fi

if check_secret "frontline-password"; then
  read -sp "Enter FRONTLINE_PASSWORD: " PASSWORD
  echo ""
  echo -n "${PASSWORD}" | gcloud secrets create frontline-password \
    --data-file=- \
    --project ${PROJECT_ID}
  echo "✅ Created frontline-password"
fi

if check_secret "firebase-credentials"; then
  read -p "Enter path to Firebase service account JSON file: " CRED_PATH
  if [ ! -f "$CRED_PATH" ]; then
    echo "❌ File not found: $CRED_PATH"
    exit 1
  fi
  gcloud secrets create firebase-credentials \
    --data-file="${CRED_PATH}" \
    --project ${PROJECT_ID}
  echo "✅ Created firebase-credentials"
fi

if check_secret "district-id"; then
  read -p "Enter DISTRICT_ID: " DISTRICT_ID
  echo -n "${DISTRICT_ID}" | gcloud secrets create district-id \
    --data-file=- \
    --project ${PROJECT_ID}
  echo "✅ Created district-id"
fi

if check_secret "firebase-project-id"; then
  read -p "Enter FIREBASE_PROJECT_ID (default: ${PROJECT_ID}): " FIREBASE_PROJECT
  FIREBASE_PROJECT=${FIREBASE_PROJECT:-${PROJECT_ID}}
  echo -n "${FIREBASE_PROJECT}" | gcloud secrets create firebase-project-id \
    --data-file=- \
    --project ${PROJECT_ID}
  echo "✅ Created firebase-project-id"
fi

# Grant Cloud Run access to secrets
echo ""
echo "🔑 Granting Cloud Run service account access to secrets..."

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
echo "You can now deploy with:"
echo "  ./deploy-cloudrun.sh"

