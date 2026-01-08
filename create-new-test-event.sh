#!/bin/bash
# Create a new test job event with unique ID

set -e

PROJECT_ID="sub67-d4648"
COLLECTION="job_events"

# Generate unique event ID using timestamp
TIMESTAMP=$(date +%s)
TEST_DATA="alpine_school_district|TEST${TIMESTAMP}|2026-01-06|08:00 AM|Test School"
EVENT_ID=$(echo -n "$TEST_DATA" | shasum -a 256 | cut -d' ' -f1)

echo "🔑 Getting access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token --project="$PROJECT_ID")

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Error: Could not get access token"
    exit 1
fi

# Get current timestamp in RFC3339 format
TIMESTAMP_RFC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create Firestore document JSON
DOC_JSON=$(cat <<EOF
{
  "fields": {
    "source": {"stringValue": "frontline"},
    "controllerId": {"stringValue": "controller_1"},
    "districtId": {"stringValue": "alpine_school_district"},
    "jobId": {"stringValue": "TEST${TIMESTAMP}"},
    "jobUrl": {"stringValue": "https://absencesub.frontlineeducation.com/Substitute/Home#/job/TEST${TIMESTAMP}"},
    "snapshotText": {"stringValue": "TITLE: Math Teacher Test\nDATE: 2026-01-06\nSTART TIME: 08:00 AM\nEND TIME: 03:00 PM\nLOCATION: Test School\nTEACHER: Test Teacher"},
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
    "createdAt": {"timestampValue": "${TIMESTAMP_RFC}"},
    "jobData": {
      "mapValue": {
        "fields": {
          "title": {"stringValue": "Math Teacher Test"},
          "date": {"stringValue": "2026-01-06"},
          "startTime": {"stringValue": "08:00 AM"},
          "endTime": {"stringValue": "03:00 PM"},
          "location": {"stringValue": "Test School"},
          "teacher": {"stringValue": "Test Teacher"},
          "confirmationNumber": {"stringValue": "TEST${TIMESTAMP}"}
        }
      }
    }
  }
}
EOF
)

echo "📝 Creating new test job event..."
echo "   Event ID: ${EVENT_ID:0:16}..."
echo "   Job ID: TEST${TIMESTAMP}"
echo ""

URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?documentId=${EVENT_ID}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$DOC_JSON" \
  "$URL")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ New test job event created!"
    echo ""
    echo "The Cloud Function should trigger automatically."
    echo ""
    echo "Check logs:"
    echo "  firebase functions:log --project $PROJECT_ID"
    echo ""
    echo "View in Firestore:"
    echo "  https://console.firebase.google.com/project/$PROJECT_ID/firestore/data/~2F${COLLECTION}~2F$EVENT_ID"
else
    echo "❌ Error creating event (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

