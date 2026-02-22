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
            priority: "high",
            notification: {
                channelId: isUrgent ? "urgent_security_channel_v5" : "normal_security_channel_v5",
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
    const androidSound = isUrgent ? "urgent_alarm" : "default";
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
                channelId: isUrgent ? "urgent_security_channel_v5" : "normal_security_channel_v5",
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
exports.onSecurityRequestCreated = onDocumentCreated("security_requests/{requestId}", async (event) => {
    const data = event.data.data();
    if (!data) return;

    const requestType = data.requestType || "general";
    const isPanic = requestType === "panic_alert";
    const isUrgent = isPanic || data.priority === "urgent" || data.priority === "high";

    console.log(`Processing Security Request: ${event.params.requestId}, Type: ${requestType}`);

    const androidSound = isUrgent ? "urgent_alarm" : "default";
    const iOSSound = isUrgent ? "urgent_alarm.aiff" : "default";

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

    // ======================================================
    // CRITICAL: For panic alerts, we send a DATA-ONLY message.
    // Android behavior: when FCM has BOTH notification+data blocks
    // and the app is in background/killed, Android auto-shows the
    // notification but does NOT call onMessageReceived(). This means
    // MyFirebaseMessagingService never intercepts, and siren never starts.
    // By sending data-only, onMessageReceived() is ALWAYS called.
    // ======================================================

    let payload;

    if (isPanic) {
        // DATA-ONLY message → onMessageReceived() always fires → siren starts
        payload = {
            data: {
                type: String(requestType),
                priority: String(data.priority || 'urgent'),
                requestId: String(event.params.requestId),
                residentId: String(data.residentId || ''),
                residentName: String(data.residentName || ''),
                flatNumber: String(data.flatNumber || data.flatNo || ''),
                buildingNumber: String(data.buildingNumber || ''),
                block: String(data.block || ''),
                phone: String(data.phone || ''),
                title: title,
                body: body,
                channelId: "urgent_security_channel_v5",
                sound: "urgent_alarm",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high",
            },
            // Broadcast to Authorities and Security Guards simultaneously
            condition: "'authority' in topics || 'security' in topics"
        };
    } else {
        // Non-panic: use notification+data (standard FCM behavior)
        payload = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: String(requestType),
                priority: String(data.priority || 'normal'),
                requestId: String(event.params.requestId),
                residentId: String(data.residentId || ''),
                flatNumber: String(data.flatNumber || ''),
                buildingNumber: String(data.buildingNumber || ''),
                block: String(data.block || ''),
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high",
                notification: {
                    channelId: isUrgent ? "urgent_security_channel_v5" : "normal_security_channel_v5",
                    sound: isUrgent ? "urgent_alarm" : "default",
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
            },
            condition: "'authority' in topics || 'security' in topics"
        };
    }

    try {
        const response = await admin.messaging().send(payload);
        console.log(`Successfully sent Security Request Topic Broadcast. Response:`, response);

        // CREATE IN-APP NOTIFICATIONS FOR DROPDOWN
        const batch = admin.firestore().batch();
        const notifData = {
            title: title,
            message: body,
            type: requestType,
            priority: data.priority || (isUrgent ? 'urgent' : 'normal'),
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            route: '/security_requests',
            silentData: true // Instructs onNotificationCreated NOT to send another FCM push
        };

        // 1. Send to Authority using their existing role-based check
        const authRef = admin.firestore().collection('notifications').doc();
        batch.set(authRef, { ...notifData, toRole: 'authority' });

        // 2. Fetch all workers and send individually (Flutter 'security' role checks toUid)
        const workersSnapshot = await admin.firestore().collection('workers').get();
        workersSnapshot.forEach(doc => {
            const workerData = doc.data();
            const workerRole = (workerData.role || "").toLowerCase();
            // Match any "security" or "guard" role
            if (workerRole.includes('security') || workerRole.includes('guard')) {
                const secRef = admin.firestore().collection('notifications').doc();
                batch.set(secRef, { ...notifData, toUid: doc.id, toRole: 'security' });
            }
        });

        await batch.commit();
        console.log("Created silent in-app notification documents for authority and all security guards.");

    } catch (error) {
        console.error("Error sending Security Request FCM Broadcast:", error);
    }
});
