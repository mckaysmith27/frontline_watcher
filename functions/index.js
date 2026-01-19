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

    // Update analytics histogram (15-minute buckets, start time).
    // This is incremental; use the backfill function once to include historical data.
    try {
      await updateJobStartTimeHistogram(event);
    } catch (e) {
      console.warn('[Analytics] Failed to update start-time histogram:', e);
    }
    
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

// -------------------------
// Analytics: start time histogram (15-minute buckets)
// -------------------------

function histogramDocId(scope, districtId) {
  if (scope === 'district' && districtId) return `district_${districtId}`;
  return 'global';
}

function timeToBucketIdx(startMinutes) {
  if (!Number.isFinite(startMinutes)) return null;
  const idx = Math.floor(startMinutes / 15);
  if (idx < 0 || idx >= 96) return null;
  return idx;
}

async function updateJobStartTimeHistogram(event) {
  const db = admin.firestore();
  const districtId = event.districtId || event.jobData?.districtId || null;
  const startMinutes = parseTimeToMinutes(event.jobData?.startTime || event.jobData?.start || event.startTime);
  const idx = timeToBucketIdx(startMinutes);
  if (idx == null) return;

  const updates = {
    [`buckets.${idx}`]: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // global
  await db.collection('job_time_histograms').doc(histogramDocId('global')).set(updates, { merge: true });
  // per district
  if (districtId) {
    await db.collection('job_time_histograms').doc(histogramDocId('district', districtId)).set(updates, { merge: true });
  }
}

exports.getJobStartTimeHistogram = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  const scope = data?.scope === 'district' ? 'district' : 'global';
  const districtId = typeof data?.districtId === 'string' ? data.districtId : null;

  const docId = histogramDocId(scope, districtId);
  const snap = await db.collection('job_time_histograms').doc(docId).get();
  const bucketsMap = snap.exists ? (snap.data()?.buckets || {}) : {};

  const buckets = [];
  for (let i = 0; i < 96; i++) {
    const v = bucketsMap?.[String(i)] ?? bucketsMap?.[i] ?? 0;
    buckets.push(typeof v === 'number' ? v : 0);
  }

  return {
    scope,
    districtId,
    buckets,
  };
});

// Optional admin-only backfill (paged). Call repeatedly until {done:true}.
exports.backfillJobStartTimeHistogram = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const db = admin.firestore();
  const scope = data?.scope === 'district' ? 'district' : 'global';
  const districtId = typeof data?.districtId === 'string' ? data.districtId : null;
  const pageSize = Math.min(Math.max(parseInt(data?.pageSize || 500, 10), 50), 1000);
  const startAfterId = typeof data?.startAfterId === 'string' ? data.startAfterId : null;

  let q = db.collection('job_events').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
  if (startAfterId) q = q.startAfter(startAfterId);

  const snap = await q.get();
  let processed = 0;
  let lastId = null;

  for (const doc of snap.docs) {
    lastId = doc.id;
    const event = doc.data();
    if (scope === 'district' && districtId && event.districtId !== districtId) continue;
    await updateJobStartTimeHistogram(event);
    processed += 1;
  }

  const done = snap.empty || snap.size < pageSize;
  return { processed, lastId, done };
});

// -------------------------
// Growth KPIs + lightweight analytics events
// -------------------------

async function requireAppAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const snap = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const data = snap.data() || {};
  const roles = Array.isArray(data.userRoles) ? data.userRoles.map(r => String(r).toLowerCase()) : [];
  const legacyIsAdmin = data.isAdmin === true || data.role === 'admin';
  const isAppAdmin = roles.includes('app admin') || legacyIsAdmin;
  if (!isAppAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'App admin access required');
  }
  return { uid: context.auth.uid, user: data };
}

function toMillis(ts) {
  if (!ts) return null;
  if (typeof ts.toDate === 'function') return ts.toDate().getTime();
  if (ts instanceof Date) return ts.getTime();
  return null;
}

function daysAgoStart(days) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - days);
  return d;
}

function tierPriceUsdFromTierName(tier) {
  // Keep in sync with `lib/config/app_config.dart` subscriptionTiers.
  // If tier names differ, we fall back to 0 (and the UI will show "approx").
  const map = {
    weekly: 4.99,
    monthly: 14.99,
    yearly: 99.99,
  };
  const key = typeof tier === 'string' ? tier.toLowerCase() : '';
  return map[key] ?? 0;
}

exports.logAnalyticsEvent = functions.https.onCall(async (data, context) => {
  const type = typeof data?.type === 'string' ? data.type.trim() : '';
  const shortname = typeof data?.shortname === 'string' ? data.shortname.trim().toLowerCase() : null;
  const meta = (data?.meta && typeof data.meta === 'object') ? data.meta : null;

  if (!type) {
    throw new functions.https.HttpsError('invalid-argument', 'type is required');
  }

  // Allow unauthenticated calls (teacher landing is public).
  const uid = context.auth?.uid ?? null;

  await admin.firestore().collection('analytics_events').add({
    type,
    shortname,
    uid,
    meta,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

exports.getGrowthKpis = functions.https.onCall(async (data, context) => {
  await requireAppAdmin(context);

  const engine = typeof data?.engine === 'string' ? data.engine.toLowerCase() : '';
  const db = admin.firestore();

  const now = Date.now();
  const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

  // Helpers to fetch counts
  async function countAnalytics(type) {
    const snap = await db
      .collection('analytics_events')
      .where('type', '==', type)
      .where('createdAt', '>=', thirtyDaysAgo)
      .get();
    return snap.size;
  }

  if (engine === 'viral') {
    const linkVisits = await countAnalytics('business_card_link_visit');
    const bookingStarts = await countAnalytics('teacher_booking_started');
    const shares = await countAnalytics('business_card_link_shared');

    const inviteAcceptanceRate = linkVisits > 0 ? bookingStarts / linkVisits : null;
    // K-factor (approx): shares per unique sharer * (bookingStarts/shares)
    const sharersSnap = await db
      .collection('analytics_events')
      .where('type', '==', 'business_card_link_shared')
      .where('createdAt', '>=', thirtyDaysAgo)
      .where('uid', '!=', null)
      .get();
    const uniqueSharers = new Set(sharersSnap.docs.map(d => d.data().uid).filter(Boolean)).size;
    const invitesPerUser = uniqueSharers > 0 ? shares / uniqueSharers : null;
    const shareToStart = shares > 0 ? bookingStarts / shares : null;
    const kFactor = (invitesPerUser != null && shareToStart != null) ? invitesPerUser * shareToStart : null;

    // Cycle time (approx): average visit->start using same shortname within 30d.
    const visitsSnap = await db
      .collection('analytics_events')
      .where('type', '==', 'business_card_link_visit')
      .where('createdAt', '>=', thirtyDaysAgo)
      .get();
    const startsSnap = await db
      .collection('analytics_events')
      .where('type', '==', 'teacher_booking_started')
      .where('createdAt', '>=', thirtyDaysAgo)
      .get();

    const latestVisitByShortname = new Map();
    for (const doc of visitsSnap.docs) {
      const ev = doc.data();
      const sn = ev.shortname;
      const ms = toMillis(ev.createdAt);
      if (!sn || ms == null) continue;
      const prev = latestVisitByShortname.get(sn);
      if (prev == null || ms > prev) latestVisitByShortname.set(sn, ms);
    }
    let acc = 0;
    let n = 0;
    for (const doc of startsSnap.docs) {
      const ev = doc.data();
      const sn = ev.shortname;
      const ms = toMillis(ev.createdAt);
      if (!sn || ms == null) continue;
      const visitMs = latestVisitByShortname.get(sn);
      if (visitMs == null) continue;
      const delta = ms - visitMs;
      if (delta < 0) continue;
      acc += delta;
      n += 1;
    }
    const viralCycleTimeMinutes = n > 0 ? (acc / n) / 60000 : null;

    return {
      engine,
      kFactor,
      inviteAcceptanceRate,
      viralCycleTimeMinutes,
      notes:
        'Viral KPIs are currently approximated from business-card link events (share, visit, booking start) over the last 30 days.',
    };
  }

  // Sticky + Paid use user/subscription + purchases.
  const usersSnap = await db.collection('users').get();
  const users = usersSnap.docs.map(d => ({ id: d.id, ...d.data() }));

  const hasLastActive = users.some(u => u.lastActiveAt && typeof u.lastActiveAt.toDate === 'function');

  function isActiveNow(u) {
    const endsAt = u.subscriptionEndsAt;
    if (!endsAt || typeof endsAt.toDate !== 'function') return false;
    return endsAt.toDate().getTime() > Date.now();
  }

  function revenueUsd(u) {
    const actions = Array.isArray(u.purchaseActions) ? u.purchaseActions : [];
    let total = 0;
    for (const a of actions) {
      const tier = a?.tier;
      const price = tierPriceUsdFromTierName(tier);
      if (price > 0) total += price;
    }
    return total;
  }

  const payingUsers = users.filter(u => revenueUsd(u) > 0);
  const totalRevenue = payingUsers.reduce((sum, u) => sum + revenueUsd(u), 0);
  const ltvUsd = payingUsers.length > 0 ? totalRevenue / payingUsers.length : null;

  if (engine === 'sticky') {
    // Cohort retention: users created N days ago AND "active" (lastActiveAt within last 24h if available, else subscription active now).
    function cohortRetention(days) {
      const start = daysAgoStart(days + 1);
      const end = daysAgoStart(days);
      const cohort = users.filter(u => {
        const ms = toMillis(u.createdAt);
        return ms != null && ms >= start.getTime() && ms < end.getTime();
      });
      if (cohort.length === 0) return null;

      const active = cohort.filter(u => {
        if (hasLastActive) {
          const last = toMillis(u.lastActiveAt);
          return last != null && last >= (Date.now() - 24 * 60 * 60 * 1000);
        }
        return isActiveNow(u);
      });
      return active.length / cohort.length;
    }

    // Churn rate (30d): users whose subscription ended in last 30d and are not active now.
    const churned = users.filter(u => {
      const endMs = toMillis(u.subscriptionEndsAt);
      if (endMs == null) return false;
      if (endMs > Date.now()) return false;
      return endMs >= thirtyDaysAgo.getTime();
    });
    const churnRate30d = churned.length > 0 ? churned.filter(u => !isActiveNow(u)).length / churned.length : null;

    return {
      engine,
      retentionDay7: cohortRetention(7),
      retentionDay30: cohortRetention(30),
      churnRate30d,
      ltvUsd,
      notes: hasLastActive
        ? 'Retention uses lastActiveAt (24h) when available.'
        : 'Retention is currently proxied by subscriptionActive (lastActiveAt not yet widely tracked).',
    };
  }

  if (engine === 'paid') {
    // Manual CAC inputs.
    const inputsSnap = await db.collection('kpi_inputs').doc('paid').get();
    const inputs = inputsSnap.exists ? (inputsSnap.data() || {}) : {};
    const adSpendUsd30d = typeof inputs.adSpendUsd30d === 'number' ? inputs.adSpendUsd30d : null;
    const newCustomers30d = typeof inputs.newCustomers30d === 'number' ? inputs.newCustomers30d : null;
    const arpuUsd30d = typeof inputs.arpuUsd30d === 'number' ? inputs.arpuUsd30d : null;

    const cacUsd = (adSpendUsd30d != null && newCustomers30d != null && newCustomers30d > 0)
      ? (adSpendUsd30d / newCustomers30d)
      : null;

    const ltvToCac = (ltvUsd != null && cacUsd != null && cacUsd > 0) ? (ltvUsd / cacUsd) : null;

    // Payback (days): CAC / (ARPU/30)
    const cacPaybackDays = (cacUsd != null && arpuUsd30d != null && arpuUsd30d > 0)
      ? (cacUsd / (arpuUsd30d / 30))
      : null;

    return {
      engine,
      cacUsd,
      ltvToCac,
      cacPaybackDays,
      notes: 'CAC metrics require admin inputs in Firestore doc kpi_inputs/paid (adSpendUsd30d, newCustomers30d, optional arpuUsd30d).',
    };
  }

  throw new functions.https.HttpsError('invalid-argument', 'Unknown engine. Use sticky|viral|paid.');
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
  // ---- Availability gating ----
  const jobDateStr = normalizeJobDate(event.jobData?.date);

  // Fully unavailable day (red)
  if (jobDateStr && Array.isArray(user.excludedDates) && user.excludedDates.includes(jobDateStr)) {
    return false;
  }

  // Already has a job that day (blue)
  if (jobDateStr && Array.isArray(user.scheduledJobDates) && user.scheduledJobDates.includes(jobDateStr)) {
    return false;
  }

  // Partial availability (mustard): exclude jobs that overlap the user's unavailable window.
  if (jobDateStr && user.partialAvailabilityByDate && user.partialAvailabilityByDate[jobDateStr]) {
    const window = user.partialAvailabilityByDate[jobDateStr];
    const startMinutes = window?.startMinutes;
    const endMinutes = window?.endMinutes;
    if (Number.isInteger(startMinutes) && Number.isInteger(endMinutes)) {
      const jobStart = parseTimeToMinutes(event.jobData?.startTime || event.jobData?.start || event.startTime);
      const jobEnd = parseTimeToMinutes(event.jobData?.endTime || event.jobData?.end || event.endTime);
      if (jobStart != null && jobEnd != null) {
        if (rangesOverlap(jobStart, jobEnd, startMinutes, endMinutes)) {
          return false;
        }
      }
    }
  }

  // Keyword filtering is opt-in via Notifications UI.
  // If not enabled (or not subscribed), match everything in the district.
  const applyFilterEnabled = user.applyFilterEnabled === true && isSubscriptionActive(user);
  if (!applyFilterEnabled) {
    return true;
  }

  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  // Get user's automation config (preferences)
  // Flutter app saves: automationConfig.includedWords and automationConfig.excludedWords
  const automationConfig = user.automationConfig || {};
  // Prefer the provider-backed fields (auto-saved from the Filters screen)
  const includedWords = user.includedLs || automationConfig.includedWords || [];
  const excludedWords = user.excludeLs || automationConfig.excludedWords || [];
  
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

function isSubscriptionActive(user) {
  const endsAt = user.subscriptionEndsAt;
  if (!endsAt || typeof endsAt.toDate !== 'function') return false;
  return endsAt.toDate().getTime() > Date.now();
}

function normalizeJobDate(v) {
  if (!v || typeof v !== 'string') return null;
  const s = v.trim();
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m) return s;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function parseTimeToMinutes(v) {
  if (!v) return null;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v !== 'string') return null;
  const s = v.trim();
  let m = s.match(/^(\d{1,2}):(\d{2})$/);
  if (m) return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
  m = s.match(/^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/);
  if (m) {
    let h = parseInt(m[1], 10);
    const min = parseInt(m[2], 10);
    const ampm = m[3].toUpperCase();
    if (ampm === 'PM' && h !== 12) h += 12;
    if (ampm === 'AM' && h === 12) h = 0;
    return h * 60 + min;
  }
  return null;
}

function rangesOverlap(aStart, aEnd, bStart, bEnd) {
  const a0 = Math.min(aStart, aEnd);
  const a1 = Math.max(aStart, aEnd);
  const b0 = Math.min(bStart, bEnd);
  const b1 = Math.max(bStart, bEnd);
  return a0 < b1 && b0 < a1;
}

/**
 * Create user-level job event record in users/{uid}/matched_jobs/{eventId}
 */
async function createUserJobEventRecord(userId, eventId, event) {
  const db = admin.firestore();
  const userJobRef = db.collection('users').doc(userId).collection('matched_jobs').doc(eventId);
  
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data() || {};

  // Extract matched keywords for this user
  const automationConfig = user.automationConfig || {};
  const includedWords = user.includedLs || automationConfig.includedWords || [];
  const matchedKeywords = [];
  
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  // Find which included keywords matched
  const applyFilterEnabled = user.applyFilterEnabled === true && isSubscriptionActive(user);
  if (applyFilterEnabled) {
    for (const term of includedWords) {
      if (matchesKeyword(text, keywords, term)) {
        matchedKeywords.push(term);
      }
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
  const includedWords = user.includedLs || automationConfig.includedWords || [];
  const matchedKeywords = [];
  const text = (event.snapshotText || '').toLowerCase();
  const keywords = new Set((event.keywords || []).map(k => k.toLowerCase()));
  
  const applyFilterEnabled = user.applyFilterEnabled === true && isSubscriptionActive(user);
  if (applyFilterEnabled) {
    for (const term of includedWords) {
      if (matchesKeyword(text, keywords, term)) {
        matchedKeywords.push(term);
      }
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

/**
 * Cloud Function to check if user is admin
 */
exports.isAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const userData = userDoc.data();

  return {
    isAdmin: userData?.role === 'admin' || userData?.isAdmin === true,
  };
});

/**
 * Cloud Function to block user completely
 */
exports.blockUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { postId, userId } = data;
  if (!postId || !userId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId and userId are required');
  }

  // Check if user is admin
  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  // Get user document to extract IPs if available
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const userData = userDoc.data();

  // Mark user as blocked
  await admin.firestore().collection('users').doc(userId).update({
    isBlocked: true,
    blockedAt: admin.firestore.FieldValue.serverTimestamp(),
    blockedBy: context.auth.uid,
    blockedReason: 'Malicious user - blocked by admin',
  });

  // Store blocked IPs if available
  const ipAddresses = userData?.ipAddresses || [];
  if (ipAddresses.length > 0) {
    await admin.firestore().collection('blocked_ips').doc(userId).set({
      userId: userId,
      ipAddresses: ipAddresses,
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      blockedBy: context.auth.uid,
    });
  }

  // Update post to mark user as blocked
  await admin.firestore().collection('posts').doc(postId).update({
    approvalStatus: 'rejected',
    blockedReason: 'User blocked by admin',
  });

  // Delete all posts by this user
  const userPostsSnapshot = await admin.firestore()
    .collection('posts')
    .where('userId', '==', userId)
    .get();

  const batch = admin.firestore().batch();
  userPostsSnapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  return { success: true };
});

/**
 * Cloud Function to block image from post
 */
exports.blockImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId is required');
  }

  // Check if user is admin
  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  await admin.firestore().collection('posts').doc(postId).update({
    imageBlocked: true,
    approvalStatus: 'partially_approved',
    blockedReason: 'Image blocked by admin',
  });

  return { success: true };
});

/**
 * Cloud Function to block message content from post
 */
exports.blockContent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId is required');
  }

  // Check if user is admin
  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  await admin.firestore().collection('posts').doc(postId).update({
    contentBlocked: true,
    approvalStatus: 'partially_approved',
    blockedReason: 'Content blocked by admin',
  });

  return { success: true };
});

/**
 * Cloud Function to fully approve post
 */
exports.approvePost = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId is required');
  }

  // Check if user is admin
  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  await admin.firestore().collection('posts').doc(postId).update({
    approvalStatus: 'approved',
    imageBlocked: false,
    contentBlocked: false,
    blockedReason: null,
  });

  return { success: true };
});

/**
 * Cloud Function to check if a shortname is available
 */
exports.checkShortnameAvailability = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { shortname } = data;
  if (!shortname || typeof shortname !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'shortname is required');
  }

  // Validate format: at least 3 characters, 1 number
  if (shortname.length < 3) {
    return { available: false, reason: 'Must be at least 3 characters' };
  }

  if (!/\d/.test(shortname)) {
    return { available: false, reason: 'Must contain at least 1 number' };
  }

  // Check if shortname is already taken
  const db = admin.firestore();
  const usersSnapshot = await db.collection('users')
    .where('shortname', '==', shortname.toLowerCase())
    .limit(1)
    .get();

  // If current user already has this shortname, it's available to them
  if (usersSnapshot.empty) {
    return { available: true };
  }

  const existingUser = usersSnapshot.docs[0];
  if (existingUser.id === context.auth.uid) {
    return { available: true };
  }

  return { available: false, reason: 'Shortname already taken' };
});

/**
 * Cloud Function to toggle post flag (flag or unflag)
 * When 2+ users flag a post, it's sent to admin approval queue
 */
exports.togglePostFlag = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { postId, isFlagged } = data;
  if (!postId || typeof isFlagged !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'postId and isFlagged are required');
  }

  const userId = context.auth.uid;
  const db = admin.firestore();
  const postRef = db.collection('posts').doc(postId);
  const flagRef = postRef.collection('flags').doc(userId);

  // Get current post data
  const postDoc = await postRef.get();
  if (!postDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Post not found');
  }

  const postData = postDoc.data();
  let currentFlagCount = postData?.flagCount || 0;

  if (isFlagged) {
    // User is flagging the post
    await flagRef.set({
      flagged: true,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      userId: userId,
    });

    // Increment flag count
    currentFlagCount += 1;
  } else {
    // User is unflagging the post
    await flagRef.delete();

    // Decrement flag count
    currentFlagCount = Math.max(0, currentFlagCount - 1);
  }

  // Update post flag count and isFlagged status
  const updateData = {
    flagCount: currentFlagCount,
  };

  // If 2+ flags, mark as flagged and send to approval queue if not already there
  if (currentFlagCount >= 2) {
    updateData.isFlagged = true;
    
    // If post was approved, change status to pending for admin review
    if (postData?.approvalStatus === 'approved') {
      updateData.approvalStatus = 'pending';
    }
  } else {
    // Less than 2 flags, remove flagged status
    updateData.isFlagged = false;
    
    // If post was pending only due to flags (not original content), restore to approved
    // But we need to check if it was originally flagged for content
    // For now, we'll leave it as is - admin can decide
  }

  await postRef.update(updateData);

  return { 
    success: true, 
    flagCount: currentFlagCount,
    isFlagged: currentFlagCount >= 2,
  };
});

/**
 * Cloud Function to get user data by shortname (for public booking page)
 */
exports.getUserByShortname = functions.https.onCall(async (data, context) => {
  const { shortname } = data;
  if (!shortname || typeof shortname !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'shortname is required');
  }

  const db = admin.firestore();
  const usersSnapshot = await db.collection('users')
    .where('shortname', '==', shortname.toLowerCase())
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }

  const userDoc = usersSnapshot.docs[0];
  const userData = userDoc.data();
  
  // Get Firebase Auth user for email
  let email = null;
  try {
    const authUser = await admin.auth().getUser(userDoc.id);
    email = authUser.email;
  } catch (e) {
    // User might not exist in Auth
  }

  // Return public profile data only
  return {
    shortname: userData.shortname || null,
    firstName: userData.firstName || null,
    lastName: userData.lastName || null,
    bio: userData.bio || null,
    cardInstructions: userData.cardInstructions || null,
    phone: userData.phoneNumber || null,
    email: email,
    photoUrl: userData.photoUrl || null,
  };
});

/**
 * Generate random order ID (7 alphanumeric characters)
 */
function generateOrderId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 7; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Cloud Function to create business card order
 */
exports.createBusinessCardOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { 
    orderId, 
    quantity, 
    shortname, 
    firstName, 
    lastName, 
    userPhone, 
    userEmail,
    shippingAddress, 
    shippingOption,
    basePrice,
    discount,
    totalPrice
  } = data;
  
  if (!quantity || !shippingAddress || !shortname || !firstName || !lastName) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  const userId = context.auth.uid;
  const db = admin.firestore();
  
  // Generate order ID if not provided
  const finalOrderId = orderId || generateOrderId();
  
  // Calculate shipping days based on option
  const shippingDays = shippingOption === 'express' ? 7 : 14;
  const deliveryDate = new Date();
  deliveryDate.setDate(deliveryDate.getDate() + shippingDays);
  
  // TODO: Generate printable business card image
  // This would typically use a library like canvas or call an image generation service
  // For now, we'll store a placeholder URL that can be generated later
  const cardImageUrl = null; // Will be generated and stored in Firebase Storage
  
  // Create order document
  const orderData = {
    orderId: finalOrderId,
    userId: userId,
    shortname: shortname,
    firstName: firstName,
    lastName: lastName,
    userPhone: userPhone || null,
    userEmail: userEmail || context.auth.email || null,
    orderQuantity: quantity,
    orderTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    basePrice: basePrice || 0.0,
    discount: discount || 0.0,
    discountedPrice: (basePrice || 0.0) * (1 - (discount || 0.0)),
    shippingOption: shippingOption || 'standard',
    shippingPrice: shippingOption === 'express' ? 3.99 : 0.0,
    totalPrice: totalPrice || 0.0,
    shippingAddress: shippingAddress,
    status: 'pending',
    cardImageUrl: cardImageUrl, // Will be populated when image is generated
    estimatedDelivery: deliveryDate.toISOString().split('T')[0],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  const orderRef = await db.collection('business_card_orders').add(orderData);
  
  return {
    orderId: finalOrderId,
    documentId: orderRef.id,
    totalPrice: totalPrice,
    estimatedDelivery: orderData.estimatedDelivery,
  };
});

/**
 * Cloud Function to refund a business card order
 */
exports.refundBusinessCardOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { orderId, userId, userEmail, totalPrice, refundNote } = data;
  
  if (!orderId || !userId || !userEmail || !refundNote) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Check if user is admin
  const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (adminData?.role !== 'admin' && adminData?.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const db = admin.firestore();
  
  // Get order document
  const orderQuery = await db.collection('business_card_orders')
    .where('orderId', '==', orderId)
    .limit(1)
    .get();
  
  if (orderQuery.empty) {
    throw new functions.https.HttpsError('not-found', 'Order not found');
  }
  
  const orderDoc = orderQuery.docs[0];
  const orderData = orderDoc.data();
  
  // Check if order is already refunded
  if (orderData.status === 'refunded') {
    throw new functions.https.HttpsError('failed-precondition', 'Order already refunded');
  }
  
  // Update order status
  await orderDoc.ref.update({
    status: 'refunded',
    refundNote: refundNote,
    refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    refundedBy: context.auth.uid,
  });
  
  // Get user's FCM tokens for notification
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  const fcmTokens = userData?.fcmTokens || [];
  
  // Send FCM notification to user
  if (fcmTokens.length > 0) {
    try {
      const message = {
        notification: {
          title: 'Order Refunded',
          body: `Your business card order (${orderId}) has been refunded. Check your email for details.`,
        },
        data: {
          type: 'order_refunded',
          orderId: orderId,
          totalPrice: totalPrice.toString(),
        },
        tokens: fcmTokens,
        android: {
          priority: 'high',
          notification: {
            channelId: 'job_notifications',
            sound: 'default',
            priority: 'high',
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
            },
          },
        },
      };
      
      await admin.messaging().sendEachForMulticast(message);
      console.log(`[Refund] Sent FCM notification to user ${userId}`);
    } catch (error) {
      console.error(`[Refund] Error sending FCM notification: ${error}`);
      // Don't fail the refund if notification fails
    }
  }
  
  // Send email notification
  try {
    // TODO: Integrate with email service (SendGrid, Mailgun, etc.)
    // For now, we'll create a document that can be processed by an email service
    await db.collection('email_queue').add({
      to: userEmail,
      subject: 'Order Refund - Sub67 Business Cards',
      template: 'order_refund',
      data: {
        orderId: orderId,
        totalPrice: totalPrice,
        refundNote: refundNote,
        firstName: orderData.firstName || '',
        lastName: orderData.lastName || '',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`[Refund] Queued email notification to ${userEmail}`);
  } catch (error) {
    console.error(`[Refund] Error queueing email: ${error}`);
    // Don't fail the refund if email fails
  }
  
  // TODO: Process actual refund through payment provider (Stripe, etc.)
  // This would typically involve:
  // 1. Creating a refund in Stripe
  // 2. Handling the refund webhook
  // 3. Updating order status based on refund result
  
  return {
    success: true,
    orderId: orderId,
    message: 'Order refunded successfully. User has been notified.',
  };
});
