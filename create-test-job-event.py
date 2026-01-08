#!/usr/bin/env python3
"""
Create a test job event in Firestore to test the Cloud Function.
Run: python3 create-test-job-event.py
"""

import os
import sys
import hashlib
import json
from datetime import datetime

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ Error: firebase-admin not installed")
    print("   Install with: pip install firebase-admin")
    sys.exit(1)

# Initialize Firebase Admin
service_account_path = "firebase-service-account.json"
if not os.path.exists(service_account_path):
    print(f"❌ Error: {service_account_path} not found")
    print("   Make sure the Firebase service account JSON is in the project root")
    sys.exit(1)

cred = credentials.Certificate(service_account_path)
firebase_admin.initialize_app(cred)
db = firestore.client()

def create_test_job_event():
    print("Creating test job event...")
    
    # Generate test event ID (hash of test data)
    test_data = "alpine_school_district|TEST123|2026-01-06|08:00 AM|Test School"
    event_id = hashlib.sha256(test_data.encode()).hexdigest()
    
    job_event = {
        'source': 'frontline',
        'controllerId': 'controller_1',
        'districtId': 'alpine_school_district',
        'jobId': 'TEST123',
        'jobUrl': 'https://absencesub.frontlineeducation.com/Substitute/Home#/job/TEST123',
        'snapshotText': (
            'TITLE: Math Teacher\n'
            'DATE: 2026-01-06\n'
            'START TIME: 08:00 AM\n'
            'END TIME: 03:00 PM\n'
            'LOCATION: Test School\n'
            'TEACHER: Test Teacher'
        ),
        'keywords': ['math', 'teacher', 'test', 'school', 'substitute'],
        'createdAt': firestore.SERVER_TIMESTAMP,
        'jobData': {
            'title': 'Math Teacher',
            'date': '2026-01-06',
            'startTime': '08:00 AM',
            'endTime': '03:00 PM',
            'location': 'Test School',
            'teacher': 'Test Teacher',
            'confirmationNumber': 'TEST123'
        }
    }
    
    try:
        # Check if event already exists
        event_ref = db.collection('job_events').document(event_id)
        existing = event_ref.get()
        
        if existing.exists:
            print(f"⚠️  Test event already exists: {event_id}")
            print("   Delete it first or use a different test ID")
            return
        
        # Create the event
        event_ref.set(job_event)
        
        print("✅ Test job event created!")
        print(f"   Event ID: {event_id}")
        print("   Collection: job_events")
        print("")
        print("The Cloud Function should trigger automatically.")
        print("Check logs with:")
        print("  firebase functions:log --project sub67-d4648")
        print("")
        print("Or view in Firebase Console:")
        print(f"  https://console.firebase.google.com/project/sub67-d4648/firestore/data/~2Fjob_events~2F{event_id}")
        
    except Exception as e:
        print(f"❌ Error creating test event: {e}")
        sys.exit(1)

if __name__ == "__main__":
    create_test_job_event()

