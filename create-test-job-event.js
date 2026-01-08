// Script to create a test job event in Firestore
// Run with: node create-test-job-event.js

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createTestJobEvent() {
  console.log('Creating test job event...');
  
  // Generate a test event ID (hash of test data)
  const crypto = require('crypto');
  const testData = 'alpine_school_district|TEST123|2026-01-06|08:00 AM|Test School';
  const eventId = crypto.createHash('sha256').update(testData).digest('hex');
  
  const jobEvent = {
    source: 'frontline',
    controllerId: 'controller-1',
    districtId: 'alpine_school_district',
    jobId: 'TEST123',
    jobUrl: 'https://absencesub.frontlineeducation.com/Substitute/Home#/job/TEST123',
    snapshotText: 'TITLE: Math Teacher\nDATE: 2026-01-06\nSTART TIME: 08:00 AM\nEND TIME: 03:00 PM\nLOCATION: Test School\nTEACHER: Test Teacher',
    keywords: ['math', 'teacher', 'test', 'school', 'substitute'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    jobData: {
      title: 'Math Teacher',
      date: '2026-01-06',
      startTime: '08:00 AM',
      endTime: '03:00 PM',
      location: 'Test School',
      teacher: 'Test Teacher',
      confirmationNumber: 'TEST123'
    }
  };
  
  try {
    // Check if event already exists
    const eventRef = db.collection('job_events').doc(eventId);
    const existing = await eventRef.get();
    
    if (existing.exists) {
      console.log('⚠️  Test event already exists:', eventId);
      console.log('   Delete it first or use a different test ID');
      return;
    }
    
    // Create the event
    await eventRef.set(jobEvent);
    
    console.log('✅ Test job event created!');
    console.log('   Event ID:', eventId);
    console.log('   Collection: job_events');
    console.log('');
    console.log('The Cloud Function should trigger automatically.');
    console.log('Check logs with:');
    console.log('  firebase functions:log --project sub67-d4648');
    console.log('');
    console.log('Or view in Firebase Console:');
    console.log('  https://console.firebase.google.com/project/sub67-d4648/firestore/data/~2Fjob_events~2F' + eventId);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating test event:', error);
    process.exit(1);
  }
}

createTestJobEvent();

