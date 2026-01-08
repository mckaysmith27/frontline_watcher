#!/bin/bash
# Create a test job event in Firestore using REST API
# No Python dependencies needed - uses curl and gcloud

set -e

PROJECT_ID="sub67-d4648"
COLLECTION="job_events"

# Generate event ID (hash of test data)
TEST_DATA="alpine_school_district|TEST123|2026-01-06|08:00 AM|Test School"
EVENT_ID=$(echo -n "$TEST_DATA" | shasum -a 256 | cut -d' ' -f1)

echo "🔑 Getting access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token --project="$PROJECT_ID")

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Error: Could not get access token"
    echo "   Run: gcloud auth login"
    exit 1
fi

# Get current timestamp in RFC3339 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create Firestore document JSON
DOC_JSON=$(cat <<EOF
{
  "fields": {
    "source": {"stringValue": "frontline"},
    "controllerId": {"stringValue": "controller-1"},
    "districtId": {"stringValue": "alpine_school_district"},
    "jobId": {"stringValue": "TEST123"},
    "jobUrl": {"stringValue": "https://absencesub.frontlineeducation.com/Substitute/Home#/job/TEST123"},
    "snapshotText": {"stringValue": "TITLE: Math Teacher\nDATE: 2026-01-06\nSTART TIME: 08:00 AM\nEND TIME: 03:00 PM\nLOCATION: Test School\nTEACHER: Test Teacher"},
    "keywords": {
      "arrayValue": {
        "values": [
          {"stringValue": "math"},
          {"stringValue": "teacher"},
          {"stringValue": "test"},
          {"stringValue": "school"},
          {"stringValue": "substitute"}
        ]
      }
    },
    "createdAt": {"timestampValue": "${TIMESTAMP}"},
    "jobData": {
      "mapValue": {
        "fields": {
          "title": {"stringValue": "Math Teacher"},
          "date": {"stringValue": "2026-01-06"},
          "startTime": {"stringValue": "08:00 AM"},
          "endTime": {"stringValue": "03:00 PM"},
          "location": {"stringValue": "Test School"},
          "teacher": {"stringValue": "Test Teacher"},
          "confirmationNumber": {"stringValue": "TEST123"}
        }
      }
    }
  }
}
EOF
)

echo "📝 Creating test job event..."
echo "   Event ID: ${EVENT_ID:0:16}..."
echo "   Collection: $COLLECTION"
echo ""

# Try to create the document
URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?documentId=${EVENT_ID}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$DOC_JSON" \
  "$URL")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ Test job event created successfully!"
    echo ""
    echo "The Cloud Function should trigger automatically."
    echo ""
    echo "Next steps:"
    echo "  1. Check Cloud Function logs:"
    echo "     firebase functions:log --project $PROJECT_ID"
    echo ""
    echo "  2. View in Firestore Console:"
    echo "     https://console.firebase.google.com/project/$PROJECT_ID/firestore/data/~2F${COLLECTION}~2F$EVENT_ID"
    echo ""
    echo "  3. Check for deliveries:"
    echo "     Look in job_events/$EVENT_ID/deliveries subcollection"
else
    echo "❌ Error creating event (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Make sure you're logged in: gcloud auth login"
    echo "  2. Check Firestore security rules allow writes"
    echo "  3. Verify project ID is correct: $PROJECT_ID"
    exit 1
fi

