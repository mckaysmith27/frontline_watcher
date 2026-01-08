#!/bin/bash
# Setup SSO Authentication for Cloud Run Scrapers
# This script helps you authenticate manually and upload the session to Secret Manager

set -e

PROJECT_ID="sub67-d4648"
SECRET_NAME="frontline-browser-context"
STORAGE_STATE_PATH="/tmp/frontline_storage_state.json"

echo "🔐 Setting up SSO Authentication for Cloud Run Scrapers"
echo ""

# Step 1: Run manual authentication
echo "Step 1: Manual Authentication"
echo "=============================="
echo "This will open a browser where you need to manually log in."
echo "Use one of your 5 controller accounts."
echo ""
read -p "Press Enter to start authentication (or Ctrl+C to cancel)..."
echo ""

# Check if Python script exists
if [ ! -f "save-auth-context.py" ]; then
    echo "❌ Error: save-auth-context.py not found"
    exit 1
fi

# Run the authentication script
echo "🚀 Opening browser for authentication..."
python3 save-auth-context.py

# Check if authentication was successful
if [ ! -f "$STORAGE_STATE_PATH" ]; then
    echo "❌ Error: Authentication failed - no session file created"
    echo "   Make sure you completed the login in the browser"
    exit 1
fi

echo ""
echo "✅ Authentication successful! Session saved to $STORAGE_STATE_PATH"
echo ""

# Step 2: Upload to Secret Manager
echo "Step 2: Upload to Secret Manager"
echo "================================"
echo ""

# Check if secret already exists
if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "⚠️  Secret $SECRET_NAME already exists. Creating new version..."
    gcloud secrets versions add "$SECRET_NAME" \
        --data-file="$STORAGE_STATE_PATH" \
        --project="$PROJECT_ID"
    echo "✅ New version created"
else
    echo "Creating new secret: $SECRET_NAME"
    gcloud secrets create "$SECRET_NAME" \
        --data-file="$STORAGE_STATE_PATH" \
        --project="$PROJECT_ID"
    echo "✅ Secret created"
fi

# Step 3: Grant Cloud Run access
echo ""
echo "Step 3: Grant Cloud Run Access"
echo "=============================="
echo ""

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Granting access to: $SERVICE_ACCOUNT"

gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="$PROJECT_ID"

echo "✅ Access granted"
echo ""

# Step 4: Update Cloud Run Jobs to use the secret
echo "Step 4: Update Cloud Run Jobs"
echo "=============================="
echo ""
echo "⚠️  Note: Cloud Run Jobs need to be updated to load this secret."
echo "   The scraper code already supports loading from Secret Manager."
echo "   You may need to update the job configuration to mount the secret."
echo ""
echo "   To update a job, you can:"
echo "   1. Go to Cloud Run Jobs console"
echo "   2. Edit each controller job"
echo "   3. Add secret environment variable:"
echo "      STORAGE_STATE_PATH=/tmp/frontline_storage_state.json"
echo "      And mount the secret as a file"
echo ""

echo "✅ SSO Authentication setup complete!"
echo ""
echo "Next steps:"
echo "1. Update Cloud Run Jobs to use the saved context (see above)"
echo "2. Run a test job:"
echo "   gcloud run jobs execute frontline-scraper-controller-1 --region us-central1"
echo "3. Check Firestore for job_events collection"

