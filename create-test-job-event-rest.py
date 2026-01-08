#!/usr/bin/env python3
"""
Create a test job event in Firestore using REST API (no firebase-admin needed).
Run: python3 create-test-job-event-rest.py
"""

import json
import hashlib
import requests
import os
from datetime import datetime

# Load Firebase service account
service_account_path = "firebase-service-account.json"
if not os.path.exists(service_account_path):
    print(f"❌ Error: {service_account_path} not found")
    exit(1)

with open(service_account_path, 'r') as f:
    service_account = json.load(f)

PROJECT_ID = service_account.get('project_id', 'sub67-d4648')

# Generate test event ID
test_data = "alpine_school_district|TEST123|2026-01-06|08:00 AM|Test School"
event_id = hashlib.sha256(test_data.encode()).hexdigest()

# Job event data
job_event = {
    "source": "frontline",
    "controllerId": "controller_1",
    "districtId": "alpine_school_district",
    "jobId": "TEST123",
    "jobUrl": "https://absencesub.frontlineeducation.com/Substitute/Home#/job/TEST123",
    "snapshotText": (
        "TITLE: Math Teacher\n"
        "DATE: 2026-01-06\n"
        "START TIME: 08:00 AM\n"
        "END TIME: 03:00 PM\n"
        "LOCATION: Test School\n"
        "TEACHER: Test Teacher"
    ),
    "keywords": ["math", "teacher", "test", "school", "substitute"],
    "createdAt": {"_seconds": int(datetime.now().timestamp()), "_nanoseconds": 0},
    "jobData": {
        "title": "Math Teacher",
        "date": "2026-01-06",
        "startTime": "08:00 AM",
        "endTime": "03:00 PM",
        "location": "Test School",
        "teacher": "Test Teacher",
        "confirmationNumber": "TEST123"
    }
}

# Firestore REST API endpoint
url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/job_events/{event_id}"

# Get access token using gcloud
print("🔑 Getting access token...")
import subprocess
try:
    result = subprocess.run(
        ["gcloud", "auth", "print-access-token"],
        capture_output=True,
        text=True,
        timeout=10
    )
    if result.returncode != 0:
        print("❌ Error: Could not get access token")
        print("   Make sure you're logged in: gcloud auth login")
        exit(1)
    access_token = result.stdout.strip()
except Exception as e:
    print(f"❌ Error getting access token: {e}")
    print("   Try: gcloud auth login")
    exit(1)

# Convert to Firestore document format
firestore_doc = {
    "fields": {}
}

def convert_to_firestore_value(value):
    """Convert Python value to Firestore value format"""
    if isinstance(value, str):
        return {"stringValue": value}
    elif isinstance(value, int):
        return {"integerValue": str(value)}
    elif isinstance(value, float):
        return {"doubleValue": value}
    elif isinstance(value, bool):
        return {"booleanValue": value}
    elif isinstance(value, list):
        return {"arrayValue": {"values": [convert_to_firestore_value(v) for v in value]}}
    elif isinstance(value, dict):
        if "_seconds" in value:  # Timestamp
            return {"timestampValue": f"{value['_seconds']}.{value.get('_nanoseconds', 0):09d}"}
        return {"mapValue": {"fields": {k: convert_to_firestore_value(v) for k, v in value.items()}}}
    else:
        return {"stringValue": str(value)}

for key, value in job_event.items():
    firestore_doc["fields"][key] = convert_to_firestore_value(value)

# Make the request
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

print(f"📝 Creating test job event: {event_id[:16]}...")
print(f"   Collection: job_events")
print(f"   Document ID: {event_id}")

try:
    response = requests.patch(url, json=firestore_doc, headers=headers, params={"updateMask.fieldPaths": ",".join(job_event.keys())})
    
    if response.status_code == 200:
        print("✅ Test job event created successfully!")
        print("")
        print("The Cloud Function should trigger automatically.")
        print("Check logs with:")
        print("  firebase functions:log --project sub67-d4648")
        print("")
        print("Or view in Firebase Console:")
        print(f"  https://console.firebase.google.com/project/{PROJECT_ID}/firestore/data/~2Fjob_events~2F{event_id}")
    elif response.status_code == 404:
        # Document doesn't exist, try creating it
        response = requests.post(
            f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/job_events?documentId={event_id}",
            json=firestore_doc,
            headers=headers
        )
        if response.status_code == 200:
            print("✅ Test job event created successfully!")
            print("")
            print("The Cloud Function should trigger automatically.")
            print("Check logs with:")
            print("  firebase functions:log --project sub67-d4648")
        else:
            print(f"❌ Error creating event: {response.status_code}")
            print(f"   Response: {response.text}")
    else:
        print(f"❌ Error: {response.status_code}")
        print(f"   Response: {response.text}")
        print("")
        print("Troubleshooting:")
        print("  1. Make sure you're logged in: gcloud auth login")
        print("  2. Check Firestore security rules allow writes")
        print("  3. Verify project ID is correct")
        
except Exception as e:
    print(f"❌ Error: {e}")
    print("")
    print("Troubleshooting:")
    print("  1. Install requests: pip install requests")
    print("  2. Make sure you're logged in: gcloud auth login")
    print("  3. Check network connection")

