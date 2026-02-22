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

    // Default to 'resident' topic if targetAudience is not provided
    const targetAudience = data.targetAudience || "resident";
    const priority = (data.priority || "normal").toLowerCase();

    console.log(`Processing Announcement: ${title}, Priority: ${priority}, Target: ${targetAudience}`);

    // Map the audience to the correct FCM topic
    let topicToTarget = "";
    if (targetAudience === "everyone") {
        topicToTarget = "all"; // A global topic if needed, but usually we use a condition
    } else if (targetAudience === "security") {
        topicToTarget = "'security' in topics";
    } else if (targetAudience === "authorities" || targetAudience === "authority") {
        topicToTarget = "'authority' in topics";
    } else if (targetAudience === "workers" || targetAudience === "worker") {
        topicToTarget = "'worker' in topics";
    } else {
        // default residents/users
        topicToTarget = "'resident' in topics || 'user' in topics";
    }

    // 2. Prepare the notification payload
    const isUrgent = priority === "urgent";
    const isMedium = priority === "medium";

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
            priority: "high",
            ttl: 0, // Forces immediate delivery, bypassing battery doze
            notification: {
                channelId: isUrgent ? "urgent_security_channel_v6" : (isMedium ? "medium_security_channel_v6" : "normal_security_channel_v6"),
                visibility: "public",
            }
        },
        apns: {
            payload: {
                aps: {
                    contentAvailable: true,
                    sound: isUrgent ? "urgent_alarm.aiff" : "default",
                    badge: 1,
                    alert: {
                        title: `[${category}] ${title}`,
                        body: body,
                    }
                },
            },
        }
    };

    // 3. Send via FCM Topic Condition
    try {
        let response;
        if (targetAudience === "everyone") {
            // Broad broadcast to any of the 3 main roles
            payload.condition = "'resident' in topics || 'worker' in topics || 'authority' in topics";
            response = await admin.messaging().send(payload);
        } else {
            payload.condition = topicToTarget;
            response = await admin.messaging().send(payload);
        }
        console.log(`Successfully sent topic broadcast for alert: ${title}. Response:`, response);
    } catch (error) {
        console.error("Error sending topic broadcast:", error);
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

    // Check if this is a silent in-app notification that shouldn't trigger push
    if (data.silentData === true) {
        console.log(`Skipping push notification for silent in-app notification: ${event.params.notificationId}`);
        return;
    }

    // Target logic
    const toUid = data.toUid;
    const toRole = data.toRole;

    // Preparation (Same logic as Announcements)
    const isUrgent = priority === "urgent";
    const isMedium = priority === "medium";

    const payload = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            type: String(type),
            priority: String(priority),
            toRole: String(toRole || ''),
            toUid: String(toUid || ''),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            ttl: 0, // Forces immediate delivery, bypassing battery doze
            notification: {
                channelId: isUrgent ? "urgent_security_channel_v6" : (isMedium ? "medium_security_channel_v6" : "normal_security_channel_v6"),
                visibility: "public",
            }
        },
        apns: {
            payload: {
                aps: {
                    contentAvailable: true,
                    sound: isUrgent ? "urgent_alarm.aiff" : "default",
                    badge: 1,
                    alert: {
                        title: title,
                        body: body,
                    }
                },
            },
        }
    };

    try {
        if (toRole) {
            // 1. Role-based broadcast using FCM Topics (Efficient)
            let topicCondition = "";
            if (toRole === "security") topicCondition = "'security' in topics";
            else if (toRole === "authority") topicCondition = "'authority' in topics";
            else if (toRole === "worker") topicCondition = "'worker' in topics";
            else if (toRole === "resident" || toRole === "user") topicCondition = "'resident' in topics || 'user' in topics";

            if (topicCondition) {
                payload.condition = topicCondition;
                const response = await admin.messaging().send(payload);
                console.log(`Sent role broadcast to topic condition [${topicCondition}]. Response:`, response);
                return; // Done
            }
        }

        if (toUid) {
            // 2. Direct Message to specific user (Fall back to tokens)
            // We search collections for the user's token
            const tokens = [];

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

            if (tokens.length === 0) {
                console.log(`No token found for direct notification to UID: ${toUid}`);
                return;
            }

            payload.tokens = [...new Set(tokens)];
            const response = await admin.messaging().sendEachForMulticast(payload);
            console.log(`Sent direct notification to ${response.successCount} devices for UID: ${toUid}.`);
        }
    } catch (e) {
        console.error("Error sending notification:", e);
    }
});

/**
 * NEW: Cloud Function to handle Security Requests (including Panic Alerts)
 * Listens to 'security_requests' collection.
 */
exports.onSecurityRequestCreated = onDocumentCreated(
    { document: "security_requests/{requestId}", minInstances: 1 },
    async (event) => {
        const data = event.data.data();
        if (!data) return;

        const requestType = data.requestType || "general";
        const isPanic = requestType === "panic_alert";
        const isUrgent = isPanic || data.priority === "urgent" || data.priority === "high";

        let title = "New Security Request";
        let body = `A new ${requestType.replace('_', ' ')} request was created for Flat ${data.flatNumber || 'Unknown'}.`;

        if (isPanic) {
            title = `🚨 PANIC ALERT TRIGGERED 🚨`;
            const name = data.residentName || 'Unknown Resident';
            const phone = data.phone || 'No Phone';
            const flat = data.flatNumber || data.flatNo || 'Unknown Flat';
            const building = data.buildingNumber && data.buildingNumber !== "Unknown" ? `(Bldg ${data.buildingNumber})` : '';
            const block = data.block && data.block !== "Unknown" ? `(Blk ${data.block})` : '';
            body = `Emergency! ${name} at Flat ${flat} ${building} ${block} activated the panic button. Contact: ${phone}. Please check immediately.`;
        }

        // ONE unified payload for ALL security requests.
        // - notification+data ensures onMessageReceived() fires AND Android shows tray notification
        // - NO sound field — channel controls sound (urgent channel is SILENT, SirenForegroundService plays audio)
        // - MyFirebaseMessagingService checks priority=='urgent' to start SirenForegroundService
        const payload = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: String(requestType),
                priority: isUrgent ? 'urgent' : String(data.priority || 'normal'),
                requestId: String(event.params.requestId),
                residentId: String(data.residentId || ''),
                flatNumber: String(data.flatNumber || ''),
                buildingNumber: String(data.buildingNumber || ''),
                block: String(data.block || ''),
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high",
                ttl: 0, // Forces immediate delivery, bypassing battery doze
                notification: {
                    channelId: isUrgent ? "urgent_security_channel_v6" : "normal_security_channel_v6",
                    visibility: "public",
                }
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: isUrgent ? "urgent_alarm.aiff" : "default",
                        badge: 1,
                        alert: { title: title, body: body }
                    },
                },
            },
            condition: "'authority' in topics || 'security' in topics"
        };

        try {
            // CONCURRENT: Send FCM topic broadcast + create in-app docs at the same time
            // This eliminates sequential latency (was 2-5s, now near-instant)
            const batch = admin.firestore().batch();
            const notifData = {
                title: title,
                message: body,
                type: requestType,
                priority: isUrgent ? 'urgent' : (data.priority || 'normal'),
                isRead: false,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                route: '/security_requests',
                silentData: true // Blocks onNotificationCreated from sending a 2nd FCM push
            };

            // Authority gets a role-based doc
            const authRef = admin.firestore().collection('notifications').doc();
            batch.set(authRef, { ...notifData, toRole: 'authority' });

            // Security gets a single role-based doc
            const secRef = admin.firestore().collection('notifications').doc();
            batch.set(secRef, { ...notifData, toRole: 'security' });

            const [response] = await Promise.all([
                admin.messaging().send(payload),
                batch.commit(),
            ]);
            console.log(`FCM + batch commit completed concurrently. Response:`, response);

        } catch (error) {
            console.error('Error sending Security Request FCM Broadcast:', error);
        }
    });
