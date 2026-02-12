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
    const priority = data.priority || "normal";

    const collectionsToQuery = [];
    if (targetAudience === "everyone") {
        collectionsToQuery.push("users", "workers", "authorities");
    } else {
        collectionsToQuery.push(targetAudience);
    }

    const tokens = [];

    // 1. Gather all tokens for the target audience
    for (const collectionName of collectionsToQuery) {
        const snapshot = await admin.firestore().collection(collectionName)
            .where("fcmToken", "!=", null)
            .get();

        snapshot.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token) tokens.push(token);
        });
    }

    if (tokens.length === 0) {
        console.log("No FCM tokens found for target: " + targetAudience);
        return;
    }

    // 2. Prepare the notification payload
    // 'urgent' priority uses the aggressive siren sound
    const isUrgent = priority === "urgent";
    const androidSound = isUrgent ? "urgent_alarm" : "default";
    const iOSSound = isUrgent ? "urgent_alarm.aiff" : "default";

    const payload = {
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
            priority: isUrgent ? "high" : "normal",
            notification: {
                channelId: isUrgent ? "urgent_security_channel_v3" : "normal_security_channel_v3",
                sound: androidSound,
            }
        },
        apns: {
            payload: {
                aps: {
                    sound: iOSSound,
                    badge: 1,
                },
            },
        },
        tokens: tokens,
    };

    // 3. Send via FCM
    try {
        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(`Successfully sent ${response.successCount} notifications for alert: ${title}`);
        if (response.failureCount > 0) {
            console.log(`Failed to send to ${response.failureCount} tokens.`);
        }
    } catch (error) {
        console.error("Error sending multicasts:", error);
    }
});
