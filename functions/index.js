const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Optimize costs and instances
setGlobalOptions({ maxInstances: 10, region: "asia-south1" });

/**
 * Cloud Function to send push notifications when a new announcement is created.
 * This works even when the resident's app is completely killed.
 */
exports.onAnnouncementCreated = onDocumentCreated("announcements/{announcementId}", async (event) => {
    const data = event.data.data();
    if (!data) return;

    const title = data.title || "New Announcement";
    const body = data.description || "You have a new notice from authority.";
    const category = data.category || "General";
    const targetAudience = data.targetAudience || "everyone";
    // Normalize priority to lowercase to ensure strict comparison works
    const priority = (data.priority || "normal").toLowerCase();

    console.log(`Processing Announcement: ${title}, Priority: ${priority}, Target: ${targetAudience}`);

    const tokens = [];

    // Helper to fetch tokens explicitly
    // Removing 'fcmToken != null' query checks to avoid needing composite indexes.
    const fetchTokens = async (collectionName, filterField = null, filterValue = null) => {
        let query = admin.firestore().collection(collectionName);

        if (filterField && filterValue) {
            query = query.where(filterField, "==", filterValue);
        }

        const snapshot = await query.get();
        // Filter in memory to be safe against missing indexes
        return snapshot.docs
            .map(doc => doc.data().fcmToken)
            .filter(token => token && token.length > 0);
    };

    // Logic to gather tokens based on audience
    if (targetAudience === "everyone") {
        // everyone = users + authorities + ALL workers (including security)
        const t1 = await fetchTokens("users");
        const t2 = await fetchTokens("workers");
        const t3 = await fetchTokens("authorities");
        tokens.push(...t1, ...t2, ...t3);
    } else if (targetAudience === "security") {
        // Security are stored in 'workers' collection with profession='Security'
        const t = await fetchTokens("workers", "profession", "Security");
        tokens.push(...t);
    } else {
        // Specific collection: 'users', 'workers', 'authorities'
        const t = await fetchTokens(targetAudience);
        tokens.push(...t);
    }

    if (tokens.length === 0) {
        console.log("No FCM tokens found for target: " + targetAudience);
        return;
    }

    // Remove duplicates
    const uniqueTokens = [...new Set(tokens)];

    // 2. Prepare the notification payload
    // 'urgent' priority uses the aggressive siren sound
    const isUrgent = priority === "urgent";
    const androidSound = isUrgent ? "urgent_alarm" : "default";
    const iOSSound = isUrgent ? "urgent_alarm.aiff" : "default";

    const payload = {
        // REVERT: We are going back to standard "Notification" payloads.
        // Data-only messages are failing to wake up the app on some devices (OEM restrictions).
        // By sending a proper 'notification' block with the correct 'channelId',
        // we let the Android System handle the sound/display, which works even if the app is dead.
        notification: {
            title: `[${category}] ${title}`,
            body: body,
        },
        data: {
            type: "announcement",
            priority: priority,
            category: category,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                // EXPLICITLY target the v4 channels we created in Flutter.
                // The channel already has the sound configured.
                channelId: isUrgent ? "urgent_security_channel_v4" : "normal_security_channel_v4",
                sound: androidSound,
                defaultSound: !isUrgent, // Only use default for non-urgent
                defaultVibrate_timings: !isUrgent,
                visibility: "public",
            }
        },
        apns: {
            payload: {
                aps: {
                    contentAvailable: true,
                    sound: iOSSound,
                    badge: 1,
                    alert: {
                        title: `[${category}] ${title}`,
                        body: body,
                    }
                },
            },
        },
        tokens: uniqueTokens,
    };

    // 3. Send via FCM (Multicast)
    try {
        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(`Successfully sent ${response.successCount} notifications for alert: ${title}`);
        if (response.failureCount > 0) {
            console.log(`Failed to send to ${response.failureCount} tokens.`);
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    console.log(`Token: ${uniqueTokens[idx]} Error: ${resp.error}`);
                }
            });
        }
    } catch (error) {
        console.error("Error sending multicasts:", error);
    }
});

/**
 * NEW: Cloud Function to handle direct notifications (Resident -> Security, Chat, etc.)
 * Listens to 'notifications' collection.
 */
exports.onNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const data = event.data.data();
    if (!data) return;

    const title = data.title || "New Message";
    const body = data.message || "You have a new notification.";
    const type = data.type || "general";
    const priority = (data.priority || "normal").toLowerCase();

    // Target logic
    const toUid = data.toUid;
    const toRole = data.toRole;

    const tokens = [];

    // Helper: Fetch ALL docs and filter in memory to avoid index issues
    const fetchTokens = async (collectionName, filterField = null, filterValue = null) => {
        const snapshot = await admin.firestore().collection(collectionName).get();
        return snapshot.docs
            .map(doc => {
                const d = doc.data();
                if (!d.fcmToken) return null;

                // Optional: In-memory filter
                if (filterField && filterValue) {
                    const val = d[filterField];
                    // Case-insensitive comparison for string fields
                    if (typeof val === 'string' && typeof filterValue === 'string') {
                        if (val.toLowerCase() !== filterValue.toLowerCase()) return null;
                    } else {
                        if (val !== filterValue) return null;
                    }
                }
                return d.fcmToken;
            })
            .filter(t => t && t.length > 0);
    };

    if (toUid) {
        // 1. Direct Message to specific user
        // We need to find which collection the user is in. 
        // We can try 'users' then 'workers' then 'authorities' or just parallel query.
        // Or better, NotificationService could save 'collection' but it doesn't.
        // Let's try to find their token in all 3 collections by ID.

        const checkCollection = async (coll) => {
            const doc = await admin.firestore().collection(coll).doc(toUid).get();
            if (doc.exists && doc.data().fcmToken) return doc.data().fcmToken;
            return null;
        };

        const t1 = await checkCollection("users");
        if (t1) tokens.push(t1);
        else {
            const t2 = await checkCollection("workers");
            if (t2) tokens.push(t2);
            else {
                const t3 = await checkCollection("authorities");
                if (t3) tokens.push(t3);
            }
        }

    } else if (toRole) {
        // 2. Role-based broadcast
        if (toRole === "security") {
            // Filter workers where profession is 'Security' (case-insensitive)
            const t = await fetchTokens("workers", "profession", "Security");
            tokens.push(...t);
        } else if (toRole === "authority") {
            const t = await fetchTokens("authorities");
            tokens.push(...t);
        } else if (toRole === "worker") {
            const t = await fetchTokens("workers");
            tokens.push(...t);
        } else if (toRole === "resident" || toRole === "user") {
            const t = await fetchTokens("users");
            tokens.push(...t);
        }
    }

    if (tokens.length === 0) {
        console.log(`No tokens found for notification: ${title} to UID:${toUid} / Role:${toRole}`);
        return;
    }

    const uniqueTokens = [...new Set(tokens)];

    // Preparation (Same logic as Announcements)
    const isUrgent = priority === "urgent";
    const androidSound = isUrgent ? "urgent_alarm" : "default"; // Re-verify resource name
    const iOSSound = isUrgent ? "urgent_alarm.aiff" : "default";

    const payload = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            type: type,
            priority: priority,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            // Include original data
            ...data
        },
        android: {
            priority: "high",
            notification: {
                channelId: isUrgent ? "urgent_security_channel_v4" : "normal_security_channel_v4",
                sound: androidSound,
                defaultSound: !isUrgent,
                defaultVibrate_timings: !isUrgent,
                visibility: "public",
            }
        },
        apns: {
            payload: {
                aps: {
                    contentAvailable: true,
                    sound: iOSSound,
                    badge: 1,
                    alert: {
                        title: title,
                        body: body,
                    }
                },
            },
        },
        tokens: uniqueTokens,
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(`Sent generic notification to ${response.successCount} devices.`);
    } catch (e) {
        console.error("Error sending generic notification:", e);
    }
});
