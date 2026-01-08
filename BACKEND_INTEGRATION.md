# Backend Integration Guide

This document outlines how to integrate the Flutter app with the Python automation script.

## Architecture Overview

```
Flutter App → Backend API → Python Script → ESS Website
                ↓
            Firestore (Job Data)
```

## Required API Endpoints

### 1. Start Automation
**POST** `/api/start-automation`

Request Body:
```json
{
  "userId": "firebase_user_id",
  "essUsername": "ess_username",
  "essPassword": "encrypted_password",
  "includedWords": ["math", "science"],
  "excludedWords": ["kindergarten"],
  "committedDates": ["2024-01-15", "2024-01-16"],
  "ntfyTopic": "sub67_user_id"
}
```

Response:
```json
{
  "success": true,
  "automationId": "unique_id",
  "message": "Automation started"
}
```

### 2. Stop Automation
**POST** `/api/stop-automation`

Request Body:
```json
{
  "userId": "firebase_user_id"
}
```

### 3. Sync Jobs
**GET** `/api/sync-jobs?userId=firebase_user_id`

Response:
```json
{
  "scheduledJobs": [
    {
      "id": "job_id",
      "confirmationNumber": "123456",
      "teacher": "Smith, John",
      "title": "Math Teacher",
      "date": "2024-01-15",
      "startTime": "8:00 AM",
      "endTime": "3:00 PM",
      "duration": "Full Day",
      "location": "High School"
    }
  ],
  "pastJobs": [...]
}
```

### 4. Cancel Job
**POST** `/api/cancel-job`

Request Body:
```json
{
  "userId": "firebase_user_id",
  "jobId": "job_confirmation_number"
}
```

### 5. Remove Excluded Date
**POST** `/api/remove-excluded-date`

Request Body:
```json
{
  "userId": "firebase_user_id",
  "date": "2024-01-15"
}
```

## Python Script Modifications

The `frontline_watcher.py` script needs to be modified to:

1. **Accept configuration from API** instead of environment variables:
   - Read filters from API request
   - Get credentials from secure storage (decrypted by backend)
   - Accept committed dates list

2. **Report back to API**:
   - When a job is accepted, POST to `/api/job-accepted`
   - When a job is found but filtered out, POST to `/api/job-filtered`
   - Update Firestore with job details

3. **Environment Variables** (for the backend service):
   ```python
   # Backend should set these when starting the script
   FRONTLINE_USERNAME=decrypted_username
   FRONTLINE_PASSWORD=decrypted_password
   JOB_INCLUDE_WORDS_ANY=comma,separated,words
   JOB_EXCLUDE_WORDS_ANY=excluded,words
   JOB_INCLUDE_WORDS_COUNT=dates,list
   JOB_INCLUDE_MIN_MATCHES=number_of_dates
   NTFY_TOPIC=sub67_user_id
   ```

## Example Backend Implementation (Python Flask)

```python
from flask import Flask, request, jsonify
import subprocess
import os
from cryptography.fernet import Fernet
import firebase_admin
from firebase_admin import credentials, firestore

app = Flask(__name__)

# Initialize Firebase
cred = credentials.Certificate("path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Encryption key for ESS credentials
cipher = Fernet(os.environ['ENCRYPTION_KEY'])

@app.route('/api/start-automation', methods=['POST'])
def start_automation():
    data = request.json
    userId = data['userId']
    
    # Decrypt credentials
    ess_username = cipher.decrypt(data['essUsername'].encode()).decode()
    ess_password = cipher.decrypt(data['essPassword'].encode()).decode()
    
    # Build environment variables for Python script
    env = os.environ.copy()
    env['FRONTLINE_USERNAME'] = ess_username
    env['FRONTLINE_PASSWORD'] = ess_password
    env['JOB_INCLUDE_WORDS_ANY'] = ','.join(data['includedWords'])
    env['JOB_EXCLUDE_WORDS_ANY'] = ','.join(data['excludedWords'])
    env['JOB_INCLUDE_WORDS_COUNT'] = ','.join(data['committedDates'])
    env['JOB_INCLUDE_MIN_MATCHES'] = str(len(data['committedDates']))
    env['NTFY_TOPIC'] = data.get('ntfyTopic', f'sub67_{userId}')
    
    # Start Python script as subprocess
    process = subprocess.Popen(
        ['python', 'frontline_watcher.py'],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Store process ID for later termination
    db.collection('automations').document(userId).set({
        'processId': process.pid,
        'status': 'running',
        'startedAt': firestore.SERVER_TIMESTAMP
    })
    
    return jsonify({'success': True, 'automationId': str(process.pid)})

@app.route('/api/stop-automation', methods=['POST'])
def stop_automation():
    data = request.json
    userId = data['userId']
    
    # Get process info from Firestore
    doc = db.collection('automations').document(userId).get()
    if doc.exists:
        process_id = doc.to_dict()['processId']
        # Terminate process
        os.kill(process_id, 15)  # SIGTERM
        
        # Update status
        db.collection('automations').document(userId).update({
            'status': 'stopped',
            'stoppedAt': firestore.SERVER_TIMESTAMP
        })
    
    return jsonify({'success': True})

@app.route('/api/sync-jobs', methods=['GET'])
def sync_jobs():
    userId = request.args.get('userId')
    
    # This would scrape ESS website and return jobs
    # For now, return empty arrays
    return jsonify({
        'scheduledJobs': [],
        'pastJobs': []
    })

@app.route('/api/job-accepted', methods=['POST'])
def job_accepted():
    data = request.json
    userId = data['userId']
    job = data['job']
    
    # Update Firestore
    db.collection('users').document(userId).collection('scheduledJobs').add(job)
    
    # Deduct credit
    user_ref = db.collection('users').document(userId)
    user_ref.update({
        'credits': firestore.Increment(-1)
    })
    
    return jsonify({'success': True})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

## Security Considerations

1. **Credential Encryption**: Use Fernet (symmetric encryption) or similar
2. **API Authentication**: Require Firebase ID tokens for all endpoints
3. **Process Isolation**: Run Python scripts in isolated containers/processes
4. **Rate Limiting**: Implement rate limiting on API endpoints
5. **Error Handling**: Log errors but don't expose sensitive information

## Deployment Options

1. **EC2** (AWS): Virtual machines running scrapers (current)
   - 2 controllers active
   - Cost: ~$8-10/month
2. **AWS Lambda**: Serverless functions
3. **Heroku**: Traditional hosting
4. **Docker**: Containerized deployment

## Monitoring

- Log all automation starts/stops
- Track job acceptance rates
- Monitor script health
- Alert on failures

## Next Steps

1. Set up backend server
2. Implement API endpoints
3. Modify Python script to accept API configuration
4. Set up process management (supervisor, systemd, etc.)
5. Configure encryption for credentials
6. Deploy and test




