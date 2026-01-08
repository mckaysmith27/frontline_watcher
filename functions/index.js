const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function triggered when a new job event is created in Firestore.
 * Matches the job event to users based on their preferences and sends FCM notifications.
 */
exports.onJobEventCreated = functions.firestore
  .document('job_events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const eventId = context.params.eventId;
    
    console.log(`[Dispatcher] Processing job event: ${eventId}`);
    console.log(`[Dispatcher] District: ${event.districtId}, Job ID: ${event.jobId}`);
    
    // Skip if already processed (safety check)
    const deliveriesRef = snap.ref.collection('deliveries');
    
    // Query matching users
    const matchingUsers = await findMatchingUsers(event);
    console.log(`[Dispatcher] Found ${matchingUsers.length} matching users`);
    
    // Send FCM to each matched user
    let successCount = 0;
    let failureCount = 0;
    
    for (const user of matchingUsers) {
      // Check if already delivered to this user
      const deliveryDoc = await deliveriesRef.doc(user.uid).get();
      if (deliveryDoc.exists) {
        console.log(`[Dispatcher] Already delivered to user ${user.uid}, skipping`);
        continue;
      }
      
      // Create user-level job event record
      try {
        await createUserJobEventRecord(user.uid, eventId, event);
        console.log(`[Dispatcher] Created user job event record for user ${user.uid}`);
      } catch (error) {
        console.error(`[Dispatcher] Error creating user job event record: ${error}`);
        // Continue even if record creation fails
      }
      
      // Send FCM notification
      try {
        await sendFCMNotification(user, event, eventId);
        successCount++;
        
        // Mark as delivered
        await deliveriesRef.doc(user.uid).set({
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          userId: user.uid,
          eventId: eventId,
        });
        
        console.log(`[Dispatcher] ✅ Sent notification to user ${user.uid}`);
      } catch (error) {
        failureCount++;
        console.error(`[Dispatcher] ❌ Failed to send to user ${user.uid}:`, error);
      }
      
      // Send email notification if enabled
      if (user.emailNotifications && user.email) {
        try {
          await sendEmailNotification(user, event, eventId);
          console.log(`[Dispatcher] ✅ Sent email notification to user ${user.uid}`);
        } catch (error) {
          console.error(`[Dispatcher] ❌ Failed to send email to user ${user.uid}:`, error);
          // Don't count email failures as critical
        }
      }
    }
    
    console.log(`[Dispatcher] Complete: ${successCount} sent, ${failureCount} failed`);
    return { successCount, failureCount };
  });

/**
 * Find users that match the job event based on district and filters
 */
async function findMatchingUsers(event) {
  const db = admin.firestore();
  
  // Filter by districtId - users must have this district in their districtIds array
  const usersSnapshot = await db.collection('users')
    .where('districtIds', 'array-contains', event.districtId)
    .where('notifyEnabled', '==', true)
    .get();
  
  console.log(`[Dispatcher] Found ${usersSnapshot.size} users in district ${event.districtId} with notifications enabled`);
  
  const matchingUsers = [];
  
  for (const userDoc of usersSnapshot.docs) {
    const user = userDoc.data();
    const userId = userDoc.id;
    
    // Check if user has automation active
    if (!user.automationActive) {
      continue;
    }
    
    // Apply matching logic
    if (matchesUserFilters(event, user)) {
      matchingUsers.push({
        uid: userId,
        fcmTokens: user.fcmTokens || [],
        ...user
      });
    }
  }
  
  return matchingUsers;
}

// Keyword mappings for alternative terms
const keywordMappings = {
  'pe': ['physical education', 'p.e.', 'p. e.'],
  'sped': ['special ed', 'special ed.', 'special edu', 'special education'],
  'esl': ['english sign language'],
  'ell': ['english language learning', 'english language learner'],
  'art': ['arts'],
  'half': ['half day'],
  'full': ['full day'],
};

// Duration mappings
const halfDayDurations = [
  '0100', '0115', '0130', '0145',
  '0200', '0215', '0230', '0245',
  '0300', '0315', '0330', '0345',
  '0400'
];

const fullDayDurations = [
  '0415', '0430', '0445',
  '0500', '0515', '0530', '0545',
  '0600', '0615', '0630', '0645',
  '0700', '0715', '0730', '0745',
  '0800', '0815', '0830', '0845',
  '0900', '0915'
];

function getMappedKeywords(term) {
  const termLower = term.toLowerCase().trim();
  const keywords = new Set([termLower]);
  
  // Add direct mappings
  if (keywordMappings[termLower]) {
    keywordMappings[termLower].forEach(k => keywords.add(k));
  }
  
  // Add reverse mappings (find all terms that map to this one)
  Object.keys(keywordMappings).forEach(key => {
    if (keywordMappings[key].includes(termLower)) {
      keywords.add(key);
      keywordMappings[key].forEach(k => keywords.add(k));
    }
  });
  
  return Array.from(keywords);
}

function matchesKeyword(text, keywords, term) {
  const termLower = term.toLowerCase().trim();
  const mappedKeywords = getMappedKeywords(termLower);
  
  // Check direct match
  if (text.includes(termLower) || keywords.has(termLower)) {
    return true;
  }
  
  // Check mapped keywords
  for (const mapped of mappedKeywords) {
    if (text.includes(mapped) || keywords.has(mapped)) {
      return true;
    }
  }
  
  // Check duration mappings for "half" and "full"
  if (termLower === 'half') {
    for (const duration of halfDayDurations) {
      if (keywords.has(duration)) {
        return true;
      }
    }
  } else if (termLower === 'full') {
    for (const duration of fullDayDurations) {
      if (keywords.has(duration)) {
        return true;
      }
    }
  }
  
  return false;
}

/**
 * Check if a job event matches a user's filter preferences
 */
function matchesUserFilters(event, user) {
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  // Get user's automation config (preferences)
  // Flutter app saves: automationConfig.includedWords and automationConfig.excludedWords
  const automationConfig = user.automationConfig || {};
  const includedWords = automationConfig.includedWords || [];
  const excludedWords = automationConfig.excludedWords || [];
  
  // If no filters set, match all jobs (user wants everything)
  if (includedWords.length === 0 && excludedWords.length === 0) {
    return true;
  }
  
  // Include filters (must match at least one if any are specified)
  if (includedWords.length > 0) {
    let hasIncludeMatch = false;
    for (const term of includedWords) {
      if (matchesKeyword(text, keywords, term)) {
        hasIncludeMatch = true;
        break;
      }
    }
    if (!hasIncludeMatch) {
      return false; // No include matches found
    }
  }
  
  // Exclude filters (must not match any)
  if (excludedWords.length > 0) {
    for (const term of excludedWords) {
      if (matchesKeyword(text, keywords, term)) {
        return false; // Excluded term found
      }
    }
  }
  
  return true; // Passed all filters
}

/**
 * Create user-level job event record in users/{uid}/matched_jobs/{eventId}
 */
async function createUserJobEventRecord(userId, eventId, event) {
  const db = admin.firestore();
  const userJobRef = db.collection('users').doc(userId).collection('matched_jobs').doc(eventId);
  
  // Extract matched keywords for this user
  const automationConfig = event.automationConfig || {};
  const includedWords = automationConfig.includedWords || [];
  const matchedKeywords = [];
  
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  // Find which included keywords matched
  for (const term of includedWords) {
    if (matchesKeyword(text, keywords, term)) {
      matchedKeywords.push(term);
    }
  }
  
  // Organize keywords by category
  const organizedKeywords = organizeKeywords(event.keywords || [], matchedKeywords);
  
  const userJobEvent = {
    eventId: eventId,
    jobId: event.jobId,
    jobUrl: event.jobUrl,
    districtId: event.districtId,
    controllerId: event.controllerId,
    snapshotText: event.snapshotText,
    jobData: event.jobData,
    matchedKeywords: matchedKeywords,
    organizedKeywords: organizedKeywords,
    allKeywords: event.keywords || [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await userJobRef.set(userJobEvent);
  return userJobEvent;
}

/**
 * Organize keywords into categories for better presentation
 */
function organizeKeywords(allKeywords, matchedKeywords) {
  const organized = {
    matched: matchedKeywords,
    subject: [],
    duration: [],
    location: [],
    date: [],
    other: [],
  };
  
  const durationKeywords = ['half', 'full', 'full day', 'half day'];
  const subjectKeywords = ['math', 'science', 'english', 'history', 'art', 'pe', 'sped', 'esl', 'ell'];
  
  for (const keyword of allKeywords) {
    const kw = keyword.toLowerCase();
    if (matchedKeywords.includes(kw)) {
      // Already in matched
      continue;
    } else if (durationKeywords.some(d => kw.includes(d))) {
      organized.duration.push(keyword);
    } else if (subjectKeywords.some(s => kw.includes(s))) {
      organized.subject.push(keyword);
    } else if (kw.match(/^\d{1,2}_\d{1,2}_\d{4}$/)) {
      // Date format: 1_5_2026
      organized.date.push(keyword);
    } else if (kw.length > 3) {
      organized.other.push(keyword);
    }
  }
  
  return organized;
}

/**
 * Send FCM notification to a user with enhanced data
 */
async function sendFCMNotification(user, event, eventId) {
  if (!user.fcmTokens || user.fcmTokens.length === 0) {
    console.log(`[Dispatcher] User ${user.uid} has no FCM tokens, skipping`);
    return;
  }
  
  // Extract job title from jobData or snapshotText
  let jobTitle = 'New Job Available';
  if (event.jobData && event.jobData.title) {
    jobTitle = event.jobData.title;
  } else if (event.snapshotText) {
    // Try to extract title from snapshot text
    const titleMatch = event.snapshotText.match(/TITLE:\s*(.+)/i);
    if (titleMatch) {
      jobTitle = titleMatch[1].trim();
    }
  }
  
  // Organize keywords for notification
  const automationConfig = user.automationConfig || {};
  const includedWords = automationConfig.includedWords || [];
  const matchedKeywords = [];
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  for (const term of includedWords) {
    if (matchesKeyword(text, keywords, term)) {
      matchedKeywords.push(term);
    }
  }
  
  const organizedKeywords = organizeKeywords(event.keywords || [], matchedKeywords);
  
  // Build notification body with keywords
  let notificationBody = jobTitle.length > 100 ? jobTitle.substring(0, 100) + '...' : jobTitle;
  if (matchedKeywords.length > 0) {
    notificationBody += `\nKeywords: ${matchedKeywords.slice(0, 3).join(', ')}`;
  }
  
  // Deep link to app with job URL
  const deepLink = `sub67://job/${eventId}?url=${encodeURIComponent(event.jobUrl || '')}`;
  
  const message = {
    notification: {
      title: 'New Job Available',
      body: notificationBody,
    },
    data: {
      jobUrl: event.jobUrl || '',
      jobId: event.jobId || '',
      eventId: eventId,
      districtId: event.districtId || '',
      deepLink: deepLink,
      matchedKeywords: JSON.stringify(matchedKeywords),
      organizedKeywords: JSON.stringify(organizedKeywords),
      type: 'job_match',
    },
    tokens: user.fcmTokens,
    android: {
      priority: 'high',
      notification: {
        channelId: 'job_notifications',
        sound: 'default',
        priority: 'high',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'content-available': 1,
        },
      },
    },
  };
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Dispatcher] Sent ${response.successCount}/${user.fcmTokens.length} notifications to user ${user.uid}`);
    
    // Remove invalid tokens
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(user.fcmTokens[idx]);
          console.log(`[Dispatcher] Failed token for user ${user.uid}: ${resp.error?.code}`);
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
        console.log(`[Dispatcher] Removed ${failedTokens.length} invalid tokens from user ${user.uid}`);
      }
    }
  } catch (error) {
    console.error(`[Dispatcher] Error sending FCM to user ${user.uid}:`, error);
    throw error;
  }
}

/**
 * Send email notification to user (optional)
 */
async function sendEmailNotification(user, event, eventId) {
  // This requires a service like SendGrid, Mailgun, or Firebase Extensions
  // For now, we'll use a placeholder that can be implemented with your email service
  
  const automationConfig = user.automationConfig || {};
  const includedWords = automationConfig.includedWords || [];
  const matchedKeywords = [];
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  for (const term of includedWords) {
    if (matchesKeyword(text, keywords, term)) {
      matchedKeywords.push(term);
    }
  }
  
  const organizedKeywords = organizeKeywords(event.keywords || [], matchedKeywords);
  
  // Extract job details
  const jobTitle = event.jobData?.title || 'New Job Available';
  const jobDate = event.jobData?.date || 'Date TBD';
  const jobLocation = event.jobData?.location || 'Location TBD';
  
  // Deep link to app
  const appLink = `https://sub67.app/job/${eventId}?url=${encodeURIComponent(event.jobUrl || '')}`;
  
  // Email content
  const emailSubject = `New Job Match: ${jobTitle}`;
  const emailBody = `
    <h2>New Job Available!</h2>
    <p><strong>Title:</strong> ${jobTitle}</p>
    <p><strong>Date:</strong> ${jobDate}</p>
    <p><strong>Location:</strong> ${jobLocation}</p>
    
    ${matchedKeywords.length > 0 ? `
    <h3>Matched Keywords:</h3>
    <ul>
      ${matchedKeywords.map(kw => `<li>${kw}</li>`).join('')}
    </ul>
    ` : ''}
    
    <p><a href="${appLink}">View Job in Sub67 App</a></p>
    <p><small>This job matched your filter preferences. Open the app to accept it quickly!</small></p>
  `;
  
  // TODO: Implement actual email sending using your email service
  // Example with SendGrid, Mailgun, or Firebase Extensions
  console.log(`[Email] Would send email to ${user.email} with subject: ${emailSubject}`);
  
  // Placeholder - implement with your email service
  // await sendEmailViaService(user.email, emailSubject, emailBody);
}
