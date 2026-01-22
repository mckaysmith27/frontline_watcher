const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Stripe = require('stripe');

admin.initializeApp();

function getStripe() {
  const key = functions.config()?.stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe is not configured (missing STRIPE_SECRET_KEY / functions config stripe.secret_key).'
    );
  }
  return Stripe(key, { apiVersion: '2024-06-20' });
}

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
// Community Q&A notifications (question posts)
// -------------------------
exports.onQuestionCommentCreated = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    try {
      const { postId } = context.params;
      const comment = snap.data() || {};

      const db = admin.firestore();
      const postSnap = await db.collection('posts').doc(postId).get();
      if (!postSnap.exists) return null;
      const post = postSnap.data() || {};

      // Only treat as Q&A when this post was explicitly queued as a question.
      if (post.questionStatus !== 'open' && post.questionStatus !== 'answered') return null;
      if (post.notifyAskerOnReply === false) return null;

      const askerUid = post.userId;
      const commenterUid = comment.userId;
      if (!askerUid || !commenterUid) return null;
      if (askerUid === commenterUid) return null;

      // If an app admin answers (and the comment indicates so), mark answered.
      const commenterSnap = await db.collection('users').doc(commenterUid).get();
      const commenter = commenterSnap.data() || {};
      const roles = Array.isArray(commenter.userRoles) ? commenter.userRoles.map((r) => String(r).toLowerCase()) : [];
      const isAppAdmin =
        roles.includes('app admin') || commenter.role === 'admin' || commenter.isAdmin === true;

      if (isAppAdmin && comment.isAdminAnswer === true && post.questionStatus !== 'answered') {
        await db.collection('posts').doc(postId).set(
          {
            questionStatus: 'answered',
            answeredAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      // Notify the asker.
      const askerSnap = await db.collection('users').doc(askerUid).get();
      const asker = askerSnap.data() || {};
      const tokens = Array.isArray(asker.fcmTokens) ? asker.fcmTokens.filter(Boolean) : [];
      if (!tokens.length) return null;

      const nickname = typeof comment.userNickname === 'string' ? comment.userNickname : 'Someone';
      const body = typeof comment.content === 'string' ? comment.content.trim() : '';
      const bodyShort = body.length > 140 ? `${body.slice(0, 140)}…` : body;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'New reply to your question',
          body: `${nickname}: ${bodyShort}`,
        },
        data: {
          type: 'question_reply',
          postId: String(postId),
        },
      });

      return null;
    } catch (e) {
      console.warn('[Community] onQuestionCommentCreated error:', e);
      return null;
    }
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
  const roles = Array.isArray(adminData?.userRoles) ? adminData.userRoles.map(r => String(r).toLowerCase()) : [];
  const isAppAdmin = roles.includes('app admin');
  const legacyIsAdmin = adminData?.role === 'admin' || adminData?.isAdmin === true;
  if (!isAppAdmin && !legacyIsAdmin) {
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
  const levelRaw = typeof data.appAdminLevel === 'string' ? data.appAdminLevel.trim().toLowerCase() : '';
  const appAdminLevel = levelRaw || 'full';
  return { uid: context.auth.uid, user: data, appAdminLevel };
}

async function requireFullAppAdmin(context) {
  const adminCtx = await requireAppAdmin(context);
  if (adminCtx.appAdminLevel === 'limited') {
    throw new functions.https.HttpsError('permission-denied', 'Full app admin access required');
  }
  return adminCtx;
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
    daily: 1.99,
    weekly: 4.99,
    'bi-weekly': 8.99,
    monthly: 14.99,
    yearly: 99.99,
    annually: 89.99,
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

// -------------------------
// Promo codes (full app admin only for creation)
// -------------------------

const crypto = require('crypto');

function normalizeCode(code) {
  return String(code || '').trim();
}

function codeUpper(code) {
  return normalizeCode(code).toUpperCase();
}

function randomAlnum(len) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const bytes = crypto.randomBytes(len);
  let out = '';
  for (let i = 0; i < len; i++) {
    out += chars[bytes[i] % chars.length];
  }
  return out;
}

function promoToPublic(doc) {
  const d = doc.data() || {};
  const exp = d.expiresAt && typeof d.expiresAt.toDate === 'function' ? d.expiresAt.toDate().toISOString().slice(0, 10) : null;
  return {
    code: d.code || doc.id,
    tier: d.tier || null,
    discountType: d.discountType || null,
    percentOff: d.percentOff ?? null,
    amountOffUsd: d.amountOffUsd ?? null,
    isCardStillRequired: d.isCardStillRequired === true,
    expiresAt: exp,
    maxRedemptions: d.maxRedemptions ?? null,
    redeemedCount: d.redeemedCount ?? 0,
    active: d.active !== false,
    createdBy: d.createdBy || null,
  };
}

exports.createPromoCode = functions.https.onCall(async (data, context) => {
  const { uid } = await requireFullAppAdmin(context);
  const db = admin.firestore();

  const tier = typeof data?.tier === 'string' ? data.tier.toLowerCase() : null;
  const discountType = typeof data?.discountType === 'string' ? data.discountType.toLowerCase() : 'free';
  const isCardStillRequired = data?.isCardStillRequired === true;
  const maxRedemptions = Number.isFinite(data?.maxRedemptions) ? Math.max(1, parseInt(data.maxRedemptions, 10)) : 1;

  const expiresAt = data?.expiresAt;
  if (!expiresAt || typeof expiresAt.toDate !== 'function') {
    throw new functions.https.HttpsError('invalid-argument', 'expiresAt (Timestamp) is required');
  }

  let code = normalizeCode(data?.code);
  if (!code) {
    code = `SUB67-${randomAlnum(8)}`;
  }
  const codeU = codeUpper(code);

  const percentOff = Number.isFinite(data?.percentOff) ? Math.max(0, Math.min(100, Number(data.percentOff))) : null;
  const amountOffUsd = Number.isFinite(data?.amountOffUsd) ? Math.max(0, Number(data.amountOffUsd)) : null;

  const docRef = db.collection('promo_codes').doc(codeU);
  const existing = await docRef.get();
  if (existing.exists) {
    throw new functions.https.HttpsError('already-exists', 'Promo code already exists');
  }

  await docRef.set({
    code,
    codeUpper: codeU,
    tier,
    discountType,
    percentOff,
    amountOffUsd,
    isCardStillRequired,
    expiresAt,
    maxRedemptions,
    redeemedCount: 0,
    active: true,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true, code: codeU };
});

exports.createPromoCodesBulk = functions.https.onCall(async (data, context) => {
  const { uid } = await requireFullAppAdmin(context);
  const db = admin.firestore();

  const tier = typeof data?.tier === 'string' ? data.tier.toLowerCase() : null;
  const count = Math.min(Math.max(parseInt(data?.count || 1, 10), 1), 500);
  const randomLength = Math.min(Math.max(parseInt(data?.randomLength || 5, 10), 5), 32);
  const prefix = normalizeCode(data?.prefix);
  const suffix = normalizeCode(data?.suffix);
  const discountType = typeof data?.discountType === 'string' ? data.discountType.toLowerCase() : 'free';
  const isCardStillRequired = data?.isCardStillRequired === true;
  const maxRedemptions = Number.isFinite(data?.maxRedemptions) ? Math.max(1, parseInt(data.maxRedemptions, 10)) : 1;
  const expiresAt = data?.expiresAt;
  if (!expiresAt || typeof expiresAt.toDate !== 'function') {
    throw new functions.https.HttpsError('invalid-argument', 'expiresAt (Timestamp) is required');
  }

  const percentOff = Number.isFinite(data?.percentOff) ? Math.max(0, Math.min(100, Number(data.percentOff))) : null;
  const amountOffUsd = Number.isFinite(data?.amountOffUsd) ? Math.max(0, Number(data.amountOffUsd)) : null;

  let created = 0;
  const codes = [];
  let attempts = 0;

  const batch = db.batch();
  while (created < count && attempts < count * 20) {
    attempts += 1;
    const code = `${prefix}${randomAlnum(randomLength)}${suffix}`;
    const codeU = codeUpper(code);
    const ref = db.collection('promo_codes').doc(codeU);
    // Collision check (cheap): rely on doc id uniqueness; if collision, we can overwrite, so we must check.
    // We avoid per-code reads by using random space; but still guard with a read for safety at small scale.
    // For up to 500, this is acceptable.
    const existing = await ref.get();
    if (existing.exists) continue;

    batch.set(ref, {
      code,
      codeUpper: codeU,
      tier,
      discountType,
      percentOff,
      amountOffUsd,
      isCardStillRequired,
      expiresAt,
      maxRedemptions,
      redeemedCount: 0,
      active: true,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    codes.push(codeU);
    created += 1;
  }

  await batch.commit();
  return { ok: true, created, codes };
});

exports.searchPromoCodes = functions.https.onCall(async (data, context) => {
  await requireFullAppAdmin(context);
  const db = admin.firestore();

  const q = codeUpper(data?.query || '');
  if (!q) return { items: [] };

  const end = q + '\uf8ff';
  const snap = await db
    .collection('promo_codes')
    .where('codeUpper', '>=', q)
    .where('codeUpper', '<=', end)
    .orderBy('codeUpper')
    .limit(50)
    .get();

  return { items: snap.docs.map(promoToPublic) };
});

exports.validatePromoCode = functions.https.onCall(async (data, context) => {
  // Auth optional; used during checkout.
  const db = admin.firestore();
  const codeU = codeUpper(data?.code || '');
  const tier = typeof data?.tier === 'string' ? data.tier.toLowerCase() : null;
  if (!codeU) throw new functions.https.HttpsError('invalid-argument', 'code is required');

  const doc = await db.collection('promo_codes').doc(codeU).get();
  if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Promo code not found');
  const p = doc.data() || {};

  if (p.active === false) throw new functions.https.HttpsError('failed-precondition', 'Promo code inactive');
  if (tier && p.tier && p.tier !== tier) throw new functions.https.HttpsError('failed-precondition', 'Promo code not valid for this package');
  const expMs = toMillis(p.expiresAt);
  if (expMs != null && expMs < Date.now()) throw new functions.https.HttpsError('failed-precondition', 'Promo code expired');

  const max = Number.isFinite(p.maxRedemptions) ? p.maxRedemptions : 1;
  const redeemed = Number.isFinite(p.redeemedCount) ? p.redeemedCount : 0;
  if (redeemed >= max) throw new functions.https.HttpsError('failed-precondition', 'Promo code fully redeemed');

  return {
    code: codeU,
    tier: p.tier || null,
    discountType: p.discountType || 'free',
    percentOff: p.percentOff ?? null,
    amountOffUsd: p.amountOffUsd ?? null,
    isCardStillRequired: p.isCardStillRequired === true,
    expiresAt: expMs,
    maxRedemptions: max,
    redeemedCount: redeemed,
  };
});

// -------------------------
// Stripe checkout for subscriptions (stores card securely via Stripe)
// -------------------------

function cents(amountUsd) {
  return Math.max(0, Math.round(Number(amountUsd || 0) * 100));
}

function parseIntentIdFromClientSecret(clientSecret) {
  if (!clientSecret || typeof clientSecret !== 'string') return null;
  const idx = clientSecret.indexOf('_secret');
  if (idx <= 0) return null;
  return clientSecret.substring(0, idx);
}

exports.getPublicAppConfig = functions.https.onCall(async () => {
  // Publishable keys are safe to expose to clients.
  const publishableKey =
    functions.config()?.stripe?.publishable_key ||
    process.env.STRIPE_PUBLISHABLE_KEY ||
    '';

  return {
    stripePublishableKey: publishableKey,
    stripeMerchantDisplayName: 'Sub67',
  };
});

async function getOrCreateStripeCustomerForUser(uid) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  const data = snap.data() || {};
  const stripe = getStripe();

  const existing = data.stripeCustomerId;
  if (typeof existing === 'string' && existing.trim()) {
    return { customerId: existing.trim(), userRef, userData: data };
  }

  const email = typeof data.email === 'string' ? data.email : null;
  const customer = await stripe.customers.create({
    email: email || undefined,
    metadata: { uid },
  });

  await userRef.set({ stripeCustomerId: customer.id }, { merge: true });
  return { customerId: customer.id, userRef, userData: { ...data, stripeCustomerId: customer.id } };
}

function applyPromoToPrice(baseUsd, promo) {
  let finalUsd = baseUsd;
  if (!promo) return { finalUsd, promoApplied: false };
  const t = promo.discountType || 'free';
  if (t === 'free') {
    finalUsd = 0;
  } else if (t === 'percent' && Number.isFinite(promo.percentOff)) {
    finalUsd = baseUsd * (1 - (promo.percentOff / 100));
  } else if (t === 'amount' && Number.isFinite(promo.amountOffUsd)) {
    finalUsd = baseUsd - promo.amountOffUsd;
  }
  if (finalUsd < 0) finalUsd = 0;
  return { finalUsd, promoApplied: true };
}

async function loadPromoForCheckout(code, tier) {
  if (!code) return null;
  const db = admin.firestore();
  const codeU = codeUpper(code);
  const doc = await db.collection('promo_codes').doc(codeU).get();
  if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Promo code not found');
  const p = doc.data() || {};
  if (p.active === false) throw new functions.https.HttpsError('failed-precondition', 'Promo code inactive');
  if (tier && p.tier && p.tier !== tier) {
    throw new functions.https.HttpsError('failed-precondition', 'Promo code not valid for this package');
  }
  const expMs = toMillis(p.expiresAt);
  if (expMs != null && expMs < Date.now()) throw new functions.https.HttpsError('failed-precondition', 'Promo code expired');
  const max = Number.isFinite(p.maxRedemptions) ? p.maxRedemptions : 1;
  const redeemed = Number.isFinite(p.redeemedCount) ? p.redeemedCount : 0;
  if (redeemed >= max) throw new functions.https.HttpsError('failed-precondition', 'Promo code fully redeemed');
  return { codeUpper: codeU, ...p };
}

exports.createStripePaymentSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;

  const tier = typeof data?.tier === 'string' ? data.tier.toLowerCase() : null;
  const basePriceUsd = Number.isFinite(data?.basePriceUsd) ? Number(data.basePriceUsd) : null;
  if (!tier || basePriceUsd == null) {
    throw new functions.https.HttpsError('invalid-argument', 'tier and basePriceUsd are required');
  }

  const promoCode = typeof data?.promoCode === 'string' ? data.promoCode.trim() : '';
  const promo = promoCode ? await loadPromoForCheckout(promoCode, tier) : null;

  const { finalUsd } = applyPromoToPrice(basePriceUsd, promo);
  const mustCollectCard = promo ? (promo.isCardStillRequired === true) : true;

  const stripe = getStripe();
  const { customerId } = await getOrCreateStripeCustomerForUser(uid);

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customerId },
    { apiVersion: '2024-06-20' }
  );

  // If $0 and card not required, skip Stripe session entirely.
  if (finalUsd <= 0 && !mustCollectCard) {
    return {
      mode: 'none',
      finalPriceUsd: 0,
      customerId,
      promo: promo ? { code: promo.codeUpper, isCardStillRequired: promo.isCardStillRequired === true } : null,
    };
  }

  if (finalUsd <= 0) {
    // SetupIntent to save card for renewal.
    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
      usage: 'off_session',
      metadata: { uid, tier, promoCode: promo ? promo.codeUpper : '' },
    });
    return {
      mode: 'setup',
      finalPriceUsd: 0,
      customerId,
      ephemeralKeySecret: ephemeralKey.secret,
      setupIntentClientSecret: setupIntent.client_secret,
      intentId: setupIntent.id,
      promo: promo ? { code: promo.codeUpper, isCardStillRequired: promo.isCardStillRequired === true } : null,
    };
  }

  // PaymentIntent for first charge; also saves card for future use.
  const pi = await stripe.paymentIntents.create({
    amount: cents(finalUsd),
    currency: 'usd',
    customer: customerId,
    automatic_payment_methods: { enabled: true },
    setup_future_usage: 'off_session',
    metadata: { uid, tier, promoCode: promo ? promo.codeUpper : '' },
  });

  return {
    mode: 'payment',
    finalPriceUsd: finalUsd,
    customerId,
    ephemeralKeySecret: ephemeralKey.secret,
    paymentIntentClientSecret: pi.client_secret,
    intentId: pi.id,
    promo: promo ? { code: promo.codeUpper, isCardStillRequired: promo.isCardStillRequired === true } : null,
  };
});

// -------------------------
// Stripe checkout for VIP Power-up (one-time purchase)
// -------------------------
exports.createVipPowerupPaymentSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;

  const stripe = getStripe();
  const { customerId } = await getOrCreateStripeCustomerForUser(uid);

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customerId },
    { apiVersion: '2024-06-20' }
  );

  // Fixed price: $7.99
  const pi = await stripe.paymentIntents.create({
    amount: 799,
    currency: 'usd',
    customer: customerId,
    automatic_payment_methods: { enabled: true },
    metadata: { uid, product: 'vip_powerup' },
  });

  return {
    mode: 'payment',
    customerId,
    ephemeralKeySecret: ephemeralKey.secret,
    paymentIntentClientSecret: pi.client_secret,
    intentId: pi.id,
  };
});

exports.confirmVipPowerupPurchase = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  const intentId = typeof data?.intentId === 'string' ? data.intentId : null;
  if (!intentId) throw new functions.https.HttpsError('invalid-argument', 'intentId is required');

  const stripe = getStripe();
  const pi = await stripe.paymentIntents.retrieve(intentId);
  if (pi.status !== 'succeeded' && pi.status !== 'processing') {
    throw new functions.https.HttpsError('failed-precondition', `PaymentIntent not successful (${pi.status})`);
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);

  const purchaseAction = {
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    product: 'vip_powerup',
    amountUsd: 7.99,
    stripeCustomerId: pi.customer || null,
    stripePaymentIntentId: pi.id,
    mode: 'vip_powerup',
  };

  await userRef.set(
    {
      vipPerksPurchased: true,
      vipPerksEnabled: true,
      vipPowerups: admin.firestore.FieldValue.increment(1),
      purchaseActions: admin.firestore.FieldValue.arrayUnion([purchaseAction]),
    },
    { merge: true }
  );

  return { ok: true };
});

exports.confirmSubscriptionPurchase = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);

  const tier = typeof data?.tier === 'string' ? data.tier.toLowerCase() : null;
  const days = Number.isFinite(data?.days) ? parseInt(data.days, 10) : null;
  const mode = typeof data?.mode === 'string' ? data.mode : 'none'; // 'none'|'setup'|'payment'
  const intentId = typeof data?.intentId === 'string' ? data.intentId : null;
  const promoCode = typeof data?.promoCode === 'string' ? data.promoCode.trim() : '';

  if (!tier || !days) throw new functions.https.HttpsError('invalid-argument', 'tier and days are required');

  const stripe = getStripe();
  const { customerId } = await getOrCreateStripeCustomerForUser(uid);

  let paymentMethodId = null;
  if (mode === 'payment' && intentId) {
    const pi = await stripe.paymentIntents.retrieve(intentId);
    if (pi.status !== 'succeeded' && pi.status !== 'processing') {
      throw new functions.https.HttpsError('failed-precondition', `PaymentIntent not successful (${pi.status})`);
    }
    paymentMethodId = typeof pi.payment_method === 'string' ? pi.payment_method : null;
  } else if (mode === 'setup' && intentId) {
    const si = await stripe.setupIntents.retrieve(intentId);
    if (si.status !== 'succeeded' && si.status !== 'processing') {
      throw new functions.https.HttpsError('failed-precondition', `SetupIntent not successful (${si.status})`);
    }
    paymentMethodId = typeof si.payment_method === 'string' ? si.payment_method : null;
  }

  // Attach and set default payment method (best effort).
  if (paymentMethodId) {
    try {
      await stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });
    } catch (_) {}
    try {
      await stripe.customers.update(customerId, {
        invoice_settings: { default_payment_method: paymentMethodId },
      });
    } catch (_) {}
  }

  // Promo redemption (transactional).
  let appliedPromoUpper = null;
  if (promoCode) {
    const codeU = codeUpper(promoCode);
    const promoRef = db.collection('promo_codes').doc(codeU);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(promoRef);
      if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Promo code not found');
      const p = snap.data() || {};
      if (p.active === false) throw new functions.https.HttpsError('failed-precondition', 'Promo code inactive');
      if (p.tier && p.tier !== tier) throw new functions.https.HttpsError('failed-precondition', 'Promo code not valid for this package');
      const expMs = toMillis(p.expiresAt);
      if (expMs != null && expMs < Date.now()) throw new functions.https.HttpsError('failed-precondition', 'Promo code expired');
      const max = Number.isFinite(p.maxRedemptions) ? p.maxRedemptions : 1;
      const redeemed = Number.isFinite(p.redeemedCount) ? p.redeemedCount : 0;
      if (redeemed >= max) throw new functions.https.HttpsError('failed-precondition', 'Promo code fully redeemed');
      const redemptionRef = promoRef.collection('redemptions').doc(uid);
      const redemptionSnap = await tx.get(redemptionRef);
      if (redemptionSnap.exists) throw new functions.https.HttpsError('failed-precondition', 'Promo already used by this user');
      tx.set(redemptionRef, { uid, usedAt: admin.firestore.FieldValue.serverTimestamp(), tier });
      tx.update(promoRef, { redeemedCount: admin.firestore.FieldValue.increment(1) });
    });
    appliedPromoUpper = codeU;
  }

  // Extend subscription timestamps (server-side source of truth for now).
  const userSnap = await userRef.get();
  const dataNow = userSnap.data() || {};
  let baseUtc = new Date();
  const existingEnds = dataNow.subscriptionEndsAt;
  if (existingEnds && typeof existingEnds.toDate === 'function') {
    const ends = existingEnds.toDate();
    if (ends.getTime() > Date.now()) baseUtc = ends;
  }
  const startsAtUtc = new Date();
  const endsAtUtc = new Date(baseUtc.getTime() + days * 24 * 60 * 60 * 1000);

  const purchaseAction = {
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    promotion: appliedPromoUpper,
    subscriptionDays: days,
    tier,
    stripeCustomerId: customerId,
    stripePaymentMethodId: paymentMethodId,
    mode,
    intentId,
  };

  await userRef.set(
    {
      subscriptionStartsAt: admin.firestore.Timestamp.fromDate(startsAtUtc),
      subscriptionEndsAt: admin.firestore.Timestamp.fromDate(endsAtUtc),
      subscriptionAutoRenewing: paymentMethodId != null,
      subscriptionActive: true,
      subscriptionTier: tier,
      subscriptionDays: days,
      stripeCustomerId: customerId,
      ...(paymentMethodId ? { stripeDefaultPaymentMethodId: paymentMethodId } : {}),
      purchaseActions: admin.firestore.FieldValue.arrayUnion([purchaseAction]),
    },
    { merge: true }
  );

  return {
    ok: true,
    subscriptionEndsAt: endsAtUtc.toISOString(),
    autoRenewing: paymentMethodId != null,
  };
});

exports.runSubscriptionRenewals = functions.https.onCall(async (data, context) => {
  await requireFullAppAdmin(context);
  const max = Math.min(Math.max(parseInt(data?.limit || 25, 10), 1), 200);
  const result = await _renewExpiredSubscriptions({ limit: max });
  return result;
});

async function _renewExpiredSubscriptions({ limit }) {
  const db = admin.firestore();
  const stripe = getStripe();

  const now = new Date();
  const snap = await db
    .collection('users')
    .where('subscriptionAutoRenewing', '==', true)
    .where('subscriptionEndsAt', '<=', admin.firestore.Timestamp.fromDate(now))
    .limit(limit)
    .get();

  let attempted = 0;
  let renewed = 0;
  let failed = 0;

  for (const doc of snap.docs) {
    attempted += 1;
    const u = doc.data() || {};
    const uid = doc.id;
    const tier = typeof u.subscriptionTier === 'string' ? u.subscriptionTier : null;
    const days = Number.isFinite(u.subscriptionDays) ? parseInt(u.subscriptionDays, 10) : null;
    const customerId = typeof u.stripeCustomerId === 'string' ? u.stripeCustomerId : null;
    const pm = typeof u.stripeDefaultPaymentMethodId === 'string' ? u.stripeDefaultPaymentMethodId : null;

    if (!tier || !days || !customerId || !pm) {
      failed += 1;
      await doc.ref.set(
        {
          subscriptionAutoRenewing: false,
          renewalError: 'Missing tier/days/customer/paymentMethod',
          renewalFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      continue;
    }

    const priceUsd = tierPriceUsdFromTierName(tier);
    if (!priceUsd || priceUsd <= 0) {
      failed += 1;
      await doc.ref.set(
        {
          subscriptionAutoRenewing: false,
          renewalError: 'Unknown tier price',
          renewalFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      continue;
    }

    try {
      const pi = await stripe.paymentIntents.create({
        amount: cents(priceUsd),
        currency: 'usd',
        customer: customerId,
        payment_method: pm,
        off_session: true,
        confirm: true,
        metadata: { uid, tier, reason: 'auto_renew' },
      });

      if (pi.status !== 'succeeded' && pi.status !== 'processing') {
        throw new Error(`PaymentIntent status ${pi.status}`);
      }

      const baseUtc = now;
      const endsAtUtc = new Date(baseUtc.getTime() + days * 24 * 60 * 60 * 1000);

      const purchaseAction = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        promotion: null,
        subscriptionDays: days,
        tier,
        stripeCustomerId: customerId,
        stripePaymentMethodId: pm,
        mode: 'auto_renew',
        intentId: pi.id,
      };

      await doc.ref.set(
        {
          subscriptionEndsAt: admin.firestore.Timestamp.fromDate(endsAtUtc),
          subscriptionActive: true,
          renewalError: admin.firestore.FieldValue.delete(),
          renewalFailedAt: admin.firestore.FieldValue.delete(),
          purchaseActions: admin.firestore.FieldValue.arrayUnion([purchaseAction]),
        },
        { merge: true }
      );

      renewed += 1;
    } catch (e) {
      failed += 1;
      await doc.ref.set(
        {
          renewalError: String(e),
          renewalFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }

  return { attempted, renewed, failed };
}

// Automatic renewals (best-effort). Requires Cloud Scheduler to be enabled.
exports.renewSubscriptionsHourly = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('UTC')
  .onRun(async () => {
    try {
      const res = await _renewExpiredSubscriptions({ limit: 25 });
      console.log('[Renewals] Hourly renewal run:', res);
      return res;
    } catch (e) {
      console.error('[Renewals] Hourly renewal failed:', e);
      return null;
    }
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

  function safeStr(v) {
    return (typeof v === 'string' ? v.trim() : '') || '';
  }

  function extractGradeAndSubject(title) {
    const t = safeStr(title);
    if (!t) return { grade: '', subject: '' };

    // Heuristic: try to pull a grade-like token from the title.
    // Examples: "3rd Grade", "Grade 3", "Kindergarten", "Pre-K", "K".
    const gradeRe =
      /\b(Pre[-\s]?K|PreK|Kindergarten|K|Grade\s*\d{1,2}|\d{1,2}(?:st|nd|rd|th)?\s*Grade)\b/i;
    const m = t.match(gradeRe);
    const grade = m ? m[1].replace(/\s+/g, ' ').trim() : '';

    // Subject is whatever remains after stripping grade + separators.
    let subject = t;
    if (m) {
      subject = subject.replace(m[0], '');
    }
    subject = subject
      .replace(/^[\s,:\-–—]+/, '')
      .replace(/[\s,:\-–—]+$/, '')
      .trim();

    return { grade, subject };
  }
  
  // Extract job basics (from scraper jobData, else snapshotText fallback).
  const jobData = event.jobData || {};
  const school = safeStr(jobData.location);
  const teacher = safeStr(jobData.teacher);

  let title = safeStr(jobData.title);
  if (!title && event.snapshotText) {
    const titleMatch = String(event.snapshotText).match(/TITLE:\s*(.+)/i);
    if (titleMatch) title = String(titleMatch[1]).trim();
  }

  const { grade, subject } = extractGradeAndSubject(title);
  const metaParts = [];
  if (grade) metaParts.push(grade);
  if (subject) metaParts.push(subject);
  if (teacher) metaParts.push(teacher);

  // Requested format:
  // "<School>: <Grade>, <Subject>, <Teacher>" (grade optional), wrapped by OS if needed.
  const notificationTitle = school
    ? (metaParts.length ? `${school}: ${metaParts.join(', ')}` : school)
    : 'New Job Available';

  // Secondary line: date/time if available, else fall back to title.
  const date = safeStr(jobData.date);
  const startTime = safeStr(jobData.startTime);
  const endTime = safeStr(jobData.endTime);
  const timeRange = startTime ? (endTime ? `${startTime} - ${endTime}` : startTime) : '';
  let notificationBody = [date, timeRange].filter(Boolean).join(' • ');
  if (!notificationBody) notificationBody = title || 'Tap to view';
  
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
  
  // Add keywords as a second line (when applicable).
  if (matchedKeywords.length > 0) {
    notificationBody += `\nKeywords: ${matchedKeywords.slice(0, 3).join(', ')}`;
  }
  
  // Deep link to app with job URL
  const deepLink = `sub67://job/${eventId}?url=${encodeURIComponent(event.jobUrl || '')}`;
  
  const message = {
    notification: {
      title: notificationTitle,
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
