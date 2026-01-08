# Backend Refactor Plan: Scraper + Dispatcher Architecture

## Overview
Refactor Sub67 backend to use 5 shared scraper instances that publish job events to Firestore, with a separate Dispatcher component that matches events to users and sends FCM notifications.

## Part A: Refactor Scraper to Publish Job Events Only

### Files to Modify

#### 1. `frontline_watcher.py`
**Changes:**
- Remove all per-user filter logic
- Remove all `ntfy` notification code
- Remove all auto-accept logic
- Keep job extraction logic (confirmation ID, title, date/time, location, etc.)
- Add Firestore integration for publishing job events
- Add event deduplication logic

**Key Functions to Modify:**
```python
# Remove:
- All user-specific filtering
- All ntfy.send() calls
- All auto-accept/booking logic

# Add:
- publish_job_event(job_data, district_id, controller_id)
- generate_event_id(district_id, job_id, date, start_time, location)
- check_event_exists(event_id)
```

**New Job Event Structure:**
```python
job_event = {
    'source': 'frontline',
    'controllerId': controller_id,  # From ENV
    'districtId': district_id,  # From ENV
    'jobId': confirmation_number,
    'jobUrl': f'https://ess.com/job/{confirmation_number}',  # Construct from job data
    'snapshotText': readable_job_block_text,
    'keywords': extract_keywords(snapshotText),  # Lowercase unique words
    'createdAt': firestore.SERVER_TIMESTAMP,
    'jobData': {
        'title': job_title,
        'date': job_date,
        'startTime': start_time,
        'endTime': end_time,
        'location': location,
        'teacher': teacher_name,
        # ... other extracted fields
    }
}
```

**Event ID Generation:**
```python
import hashlib

def generate_event_id(district_id, job_id, date, start_time, location):
    """Generate stable hash for deduplication"""
    combined = f"{district_id}|{job_id}|{date}|{start_time}|{location}"
    return hashlib.sha256(combined.encode()).hexdigest()
```

**Firestore Write Logic:**
```python
def publish_job_event(job_event, event_id):
    """Write job event to Firestore, skip if exists"""
    event_ref = db.collection('job_events').document(event_id)
    
    # Check if exists (atomic check)
    if event_ref.get().exists:
        print(f"Event {event_id} already exists, skipping")
        return False
    
    # Write event
    event_ref.set(job_event)
    print(f"Published job event: {event_id}")
    return True
```

### New Dependencies
Add to `requirements_raw.txt`:
```
firebase-admin>=6.0.0
google-cloud-firestore>=2.0.0
```

### Environment Variables
Each scraper instance needs:
```env
CONTROLLER_ID=controller_1  # Unique ID for this instance (1-5)
DISTRICT_ID=district_12345  # Frontline district identifier
FRONTLINE_USERNAME=partner_username
FRONTLINE_PASSWORD=partner_password
FIREBASE_PROJECT_ID=sub67-d4648
FIREBASE_CREDENTIALS_PATH=/path/to/service-account.json
```

## Part B: Create Dispatcher (Cloud Functions)

### Files to Create

#### 1. `functions/index.js` (Firebase Cloud Functions)
**Structure:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Trigger on new job_event document creation
exports.onJobEventCreated = functions.firestore
  .document('job_events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const eventId = context.params.eventId;
    
    // Skip if already processed
    const deliveriesRef = snap.ref.collection('deliveries');
    
    // Query matching users
    const matchingUsers = await findMatchingUsers(event);
    
    // Send FCM to each matched user
    for (const user of matchingUsers) {
      // Check if already delivered
      const deliveryDoc = await deliveriesRef.doc(user.uid).get();
      if (deliveryDoc.exists) continue;
      
      // Send FCM notification
      await sendFCMNotification(user, event);
      
      // Mark as delivered
      await deliveriesRef.doc(user.uid).set({
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        userId: user.uid,
      });
    }
  });

async function findMatchingUsers(event) {
  const db = admin.firestore();
  
  // Filter by districtId
  const usersSnapshot = await db.collection('users')
    .where('districtIds', 'array-contains', event.districtId)
    .where('notifyEnabled', '==', true)
    .get();
  
  const matchingUsers = [];
  
  for (const userDoc of usersSnapshot.docs) {
    const user = userDoc.data();
    if (matchesUserFilters(event, user)) {
      matchingUsers.push({
        uid: userDoc.id,
        fcmTokens: user.fcmTokens || [],
        ...user
      });
    }
  }
  
  return matchingUsers;
}

function matchesUserFilters(event, user) {
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  // Include filters
  const includeAny = user.includeAny || [];
  const includeCount = user.includeCount || [];
  const includeMinMatches = user.includeMinMatches || 1;
  
  let includeMatches = 0;
  for (const term of includeAny) {
    if (text.includes(term.toLowerCase()) || keywords.has(term.toLowerCase())) {
      includeMatches++;
    }
  }
  for (const term of includeCount) {
    if (text.includes(term.toLowerCase()) || keywords.has(term.toLowerCase())) {
      includeMatches++;
    }
  }
  
  if (includeMatches < includeMinMatches) {
    return false;
  }
  
  // Exclude filters
  const excludeAny = user.excludeAny || [];
  const excludeCount = user.excludeCount || [];
  const excludeMinMatches = user.excludeMinMatches || 1;
  
  let excludeMatches = 0;
  for (const term of excludeAny) {
    if (text.includes(term.toLowerCase()) || keywords.has(term.toLowerCase())) {
      excludeMatches++;
    }
  }
  for (const term of excludeCount) {
    if (text.includes(term.toLowerCase()) || keywords.has(term.toLowerCase())) {
      excludeMatches++;
    }
  }
  
  if (excludeMatches >= excludeMinMatches) {
    return false;
  }
  
  return true;
}

async function sendFCMNotification(user, event) {
  if (!user.fcmTokens || user.fcmTokens.length === 0) {
    return;
  }
  
  const message = {
    notification: {
      title: 'New Job Available',
      body: event.jobData?.title || 'A new job matches your filters',
    },
    data: {
      jobUrl: event.jobUrl,
      jobId: event.jobId,
      eventId: event.id || '',
      districtId: event.districtId,
    },
    tokens: user.fcmTokens,
  };
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Sent ${response.successCount} notifications to user ${user.uid}`);
    
    // Remove invalid tokens
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(user.fcmTokens[idx]);
        }
      });
      
      // Remove invalid tokens from user doc
      if (failedTokens.length > 0) {
        await admin.firestore()
          .collection('users')
          .doc(user.uid)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
          });
      }
    }
  } catch (error) {
    console.error('Error sending FCM:', error);
  }
}
```

#### 2. `functions/package.json`
```json
{
  "name": "sub67-dispatcher",
  "version": "1.0.0",
  "description": "Sub67 job event dispatcher",
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  },
  "engines": {
    "node": "18"
  }
}
```

#### 3. `functions/.gitignore`
```
node_modules/
.env
*.log
```

## Part C: Firestore Schema

### Collection: `users/{uid}`
```typescript
{
  // Existing fields...
  email: string;
  username: string;
  credits: number;
  
  // New fields for matching
  districtIds: string[];  // Array of district IDs user wants jobs from
  includeAny: string[];   // Keywords that must appear (any)
  excludeAny: string[];   // Keywords that must not appear (any)
  includeCount: string[]; // Keywords to count for matching
  includeMinMatches: number; // Minimum matches from includeCount
  excludeCount: string[]; // Keywords to count for exclusion
  excludeMinMatches: number; // Minimum matches to exclude
  
  // FCM tokens
  fcmTokens: string[];    // Array of FCM device tokens
  notifyEnabled: boolean; // Whether user wants notifications
}
```

### Collection: `job_events/{eventId}`
```typescript
{
  source: "frontline";
  controllerId: string;  // Which scraper instance
  districtId: string;    // Frontline district ID
  jobId: string;         // Confirmation number
  jobUrl: string;        // URL to job details page
  snapshotText: string;  // Readable job description
  keywords: string[];    // Lowercase unique keywords
  createdAt: Timestamp;
  jobData: {
    title: string;
    date: string;
    startTime: string;
    endTime: string;
    location: string;
    teacher: string;
    // ... other fields
  };
  
  // Subcollection: deliveries/{uid}
  // Tracks which users have been notified
}
```

### Collection: `job_events/{eventId}/deliveries/{uid}`
```typescript
{
  userId: string;
  deliveredAt: Timestamp;
}
```

## Part D: Multi-Scraper Scheduling Plan

### 5 Controller Instances

**Instance 1 (controller_1):**
- Runs every 15 seconds
- Offset: 0 seconds (00:00, 00:15, 00:30, ...)
- Hot window: 6:00 AM - 8:00 AM, 2:00 PM - 4:00 PM

**Instance 2 (controller_2):**
- Runs every 15 seconds
- Offset: 3 seconds (00:03, 00:18, 00:33, ...)
- Hot window: 6:00 AM - 8:00 AM, 2:00 PM - 4:00 PM

**Instance 3 (controller_3):**
- Runs every 15 seconds
- Offset: 6 seconds (00:06, 00:21, 00:36, ...)
- Hot window: 6:00 AM - 8:00 AM, 2:00 PM - 4:00 PM

**Instance 4 (controller_4):**
- Runs every 15 seconds
- Offset: 9 seconds (00:09, 00:24, 00:39, ...)
- Hot window: 6:00 AM - 8:00 AM, 2:00 PM - 4:00 PM

**Instance 5 (controller_5):**
- Runs every 15 seconds
- Offset: 12 seconds (00:12, 00:27, 00:42, ...)
- Hot window: 6:00 AM - 8:00 AM, 2:00 PM - 4:00 PM

### Combined Cadence
- Each instance: 15-second intervals
- Combined: ~3-second effective cadence (15/5 = 3 seconds)
- During hot windows: All instances run at full speed
- Outside hot windows: Instances can reduce frequency or pause

### Implementation
```python
import time
from datetime import datetime, time as dt_time

def should_run_aggressive():
    """Check if current time is in hot window"""
    now = datetime.now().time()
    hot_windows = [
        (dt_time(6, 0), dt_time(8, 0)),   # 6-8 AM
        (dt_time(14, 0), dt_time(16, 0)), # 2-4 PM
    ]
    
    for start, end in hot_windows:
        if start <= now <= end:
            return True
    return False

def get_scraper_offset(controller_id):
    """Get offset in seconds for this controller"""
    offsets = {
        'controller_1': 0,
        'controller_2': 3,
        'controller_3': 6,
        'controller_4': 9,
        'controller_5': 12,
    }
    return offsets.get(controller_id, 0)

# In main loop:
controller_id = os.getenv('CONTROLLER_ID')
offset = get_scraper_offset(controller_id)
interval = 15 if should_run_aggressive() else 60

while True:
    if should_run_aggressive():
        # Run scraper
        run_scraper()
    
    time.sleep(interval)
    # Apply offset on first iteration
    if first_iteration:
        time.sleep(offset)
        first_iteration = False
```

## Implementation Steps

### Step 1: Update Python Scraper
1. Remove user-specific code
2. Add Firestore client initialization
3. Implement `publish_job_event()`
4. Implement `generate_event_id()`
5. Update main loop to publish events instead of notifying

### Step 2: Set Up Cloud Functions
1. Initialize Firebase Functions project
2. Create `functions/index.js` with dispatcher logic
3. Deploy function: `firebase deploy --only functions`

### Step 3: Update Firestore Schema
1. Add new fields to user documents via migration script or app updates
2. Ensure indexes are created for queries:
   - `users` collection: `districtIds` (array-contains) + `notifyEnabled` (==)
   - `job_events` collection: `createdAt` (orderBy)

### Step 4: Deploy Scrapers
1. Set up 5 separate server instances or containers
2. Configure each with unique `CONTROLLER_ID` and `DISTRICT_ID`
3. Deploy scraper code to each instance
4. Set up scheduling/cron for each instance with offsets

## Security Notes
- Never store end-user Frontline credentials in Firestore
- Only controller/partner credentials stored on scraper servers (env files)
- FCM tokens stored in Firestore (standard practice)
- Job events are read-only for end users (via security rules)

## Testing Checklist
- [ ] Scraper publishes events to Firestore
- [ ] Event deduplication works (same event not published twice)
- [ ] Cloud Function triggers on new events
- [ ] User matching logic works correctly
- [ ] FCM notifications sent to matched users
- [ ] Delivery tracking prevents duplicates
- [ ] Invalid FCM tokens removed from user docs
- [ ] Multi-scraper scheduling works as expected

