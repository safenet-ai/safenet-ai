const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onValueUpdated } = require("firebase-functions/v2/database");
const { setGlobalOptions } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Optimize costs and instances
setGlobalOptions({ maxInstances: 10, region: "asia-southeast1" });

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
        data: {
            title: `[${category}] ${title}`,
            body: body,
            type: "announcement",
            priority: priority,
            category: category,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            ttl: 0, // Forces immediate delivery, bypassing battery doze
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

    try {
        // ALWAYS send as data-only to wake up the app directly in background
        // and avoid Android OS system tray interfering

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
        data: {
            title: title,
            body: body,
            type: String(type),
            priority: String(priority),
            toRole: String(toRole || ''),
            toUid: String(toUid || ''),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            ttl: 0, // Forces immediate delivery, bypassing battery doze
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
        } else if (requestType === "smoke_alert") {
            const smokeType = data.smokeType || 'SMOKE';
            const name = data.residentName || 'Unknown Resident';
            const phone = data.phone || 'No Phone';
            const flat = data.flatNumber || 'Unknown Flat';
            const building = data.buildingNumber && data.buildingNumber !== "Unknown" ? `Bldg ${data.buildingNumber}` : '';
            const block = data.block && data.block !== "Unknown" ? `Block ${data.block}` : '';
            const ppm = data.smokePpm ? ` (${data.smokePpm}ppm)` : '';
            const device = data.deviceId || 'Unknown Room';
            title = `🔥 SMOKE ALERT — ${device.toUpperCase()} 🔥`;
            body = `${smokeType} detected${ppm} at ${device}. Resident: ${name}, Flat ${flat} ${building} ${block}. Contact: ${phone}. EVACUATE IMMEDIATELY.`;
        }

        // ONE unified payload for ALL security requests.
        // - NO top-level "notification" object initially.
        // - If urgent, it STAYS data-only. Android handles it in MyFirebaseMessagingService 
        //   (which calls SirenForegroundService which then builds the actual UI notification).
        // - If NOT urgent, we append the notification block so standard Android Tray handles it.
        const payload = {
            data: {
                title: title,
                body: body,
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
            // CONCURRENT: Send FCM topic broadcast + direct resident alert + create in-app docs
            const tasks = [];
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

            // 1. Send broadcast to security/authority topics
            tasks.push(admin.messaging().send(payload));

            // 2. Send direct alert to the resident (if UID available)
            if (data.residentId) {
                const residentTask = (async () => {
                    const residentDoc = await admin.firestore().collection("users").doc(data.residentId).get();
                    if (residentDoc.exists && residentDoc.data().fcmToken) {
                        const resPayload = {
                            ...payload,
                            token: residentDoc.data().fcmToken
                        };
                        delete resPayload.condition;

                        // Customize message for resident
                        if (requestType === "smoke_alert") {
                            resPayload.data.title = "🔥 EVACUATE IMMEDIATELY 🔥";
                            resPayload.data.body = "Smoke detected in your unit. Please leave the building now!";
                        }

                        await admin.messaging().send(resPayload);
                        console.log(`Sent direct siren alert to resident ${data.residentId}`);
                    }
                })();
                tasks.push(residentTask);

                // Add resident's in-app notification record
                const resRef = admin.firestore().collection('notifications').doc();
                batch.set(resRef, {
                    ...notifData,
                    toUid: data.residentId,
                    title: requestType === "smoke_alert" ? "🔥 EMERGENCY: EVACUATE 🔥" : notifData.title,
                    message: requestType === "smoke_alert" ? "Smoke detected. Please evacuate immediately!" : notifData.message
                });
            }

            // 3. Create in-app notifications for roles
            const authRef = admin.firestore().collection('notifications').doc();
            batch.set(authRef, { ...notifData, toRole: 'authority' });

            const secRef = admin.firestore().collection('notifications').doc();
            batch.set(secRef, { ...notifData, toRole: 'security' });

            tasks.push(batch.commit());

            const results = await Promise.all(tasks);
            console.log(`Global alert dispatch completed. Requests: ${tasks.length}. Main response: ${results[0]}`);

        } catch (error) {
            console.error('Error sending Security Request FCM Broadcast:', error);
        }
    });

/**
 * NEW: Cloud Function to detect smoke/gas alerts from ESP32 sensor gateway.
 * Triggers when the 'devices/{deviceId}' document is updated.
 * When alertTriggered=true, it looks up the resident for that room and
 * creates a security_request document — which then triggers the existing
 * onSecurityRequestCreated function to send the urgent siren notification.
 */
exports.onSmokeDetected = onDocumentUpdated("devices/{deviceId}", async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();

    if (!after) return;

    // Only proceed if alertTriggered just became true
    const alertJustTriggered = after.alertTriggered === true && before.alertTriggered !== true;
    if (!alertJustTriggered) return;

    const deviceId = event.params.deviceId;
    const smokeType = after.type || "SMOKE"; // "SMOKE" or "GAS"
    const smokePpm = after.Smoke_ppm ? Math.round(after.Smoke_ppm) : null;
    const gasPpm = after.LPG_ppm ? Math.round(after.LPG_ppm) : null;

    console.log(`🚨 Smoke Alert triggered for device: ${deviceId}, type: ${smokeType}`);

    // 1. Look up the resident assigned to this device room
    // We match users where their roomId / deviceId field matches this deviceId
    let residentName = "Unknown Resident";
    let flatNumber = "Unknown";
    let buildingNumber = "Unknown";
    let block = "Unknown";
    let phone = "Unknown";
    let residentId = null;

    try {
        // Try to find resident by flatNumber matching the deviceId
        // e.g., deviceId = "room101" — you can also add a 'deviceId' field to user docs
        const usersSnap = await admin.firestore().collection("users").get();
        for (const doc of usersSnap.docs) {
            const u = doc.data();
            // Match if the user's flat/room matches or user has a deviceId field
            const userDevice = u.deviceId || u.roomId || null;
            if (userDevice === deviceId) {
                residentId = doc.id;
                residentName = u.username || u.name || "Unknown Resident";
                flatNumber = u.flatNumber || u.flatNo || "Unknown";
                buildingNumber = u.buildingNumber || u.buildingNo || "Unknown";
                block = u.block || "Unknown";
                phone = u.phone || "Unknown";
                break;
            }
        }
    } catch (e) {
        console.error("Error fetching resident for smoke alert:", e);
    }

    // 2. Write a security_request document.
    // The existing onSecurityRequestCreated function will pick this up
    // and immediately send the urgent siren FCM notification to authority + security.
    const ppmInfo = smokePpm ? ` (Smoke: ${smokePpm}ppm, Gas: ${gasPpm}ppm)` : "";
    try {
        await admin.firestore().collection("security_requests").add({
            requestType: "smoke_alert",
            deviceId: deviceId,
            smokeType: smokeType,
            smokePpm: smokePpm,
            gasPpm: gasPpm,
            residentId: residentId,
            residentName: residentName,
            flatNumber: flatNumber,
            buildingNumber: buildingNumber,
            block: block,
            phone: phone,
            status: "pending",
            priority: "urgent",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ smoke_alert security_request created for device ${deviceId} — resident: ${residentName}`);
    } catch (e) {
        console.error("Error creating smoke_alert security_request:", e);
    }
});

/**
 * OPTIMIZED: Realtime Database Trigger for Ultra-Fast Notifications.
 * This triggers instantly when the ESP32 writes to RTDB.
 */
exports.onSmokeDetectedRTDB = onValueUpdated("/devices/{deviceId}", async (event) => {
    const after = event.data.after.val();
    const before = event.data.before.val();

    if (!after) return;

    // Only proceed if alertTriggered just became true
    const alertJustTriggered = after.alertTriggered === true && (!before || before.alertTriggered !== true);
    if (!alertJustTriggered) return;

    const deviceId = event.params.deviceId;
    const smokeType = after.type || "SMOKE";
    const smokePpm = after.Smoke_ppm ? Math.round(after.Smoke_ppm) : null;
    const gasPpm = after.LPG_ppm ? Math.round(after.LPG_ppm) : null;

    console.log(`⚡ FAST ALERT: Smoke detected on RTDB for device: ${deviceId}`);

    // High-speed Resident Lookup (Firestore Query instead of full scan)
    let residentId = null;
    let residentData = {
        name: "Unknown Resident",
        flat: "Unknown",
        building: "Unknown",
        block: "Unknown",
        phone: "Unknown"
    };

    try {
        // OPTIMIZATION: Query by roomId/deviceId directly if possible.
        // Assuming your users have a field like 'roomId' or 'deviceId'
        const userQuery = await admin.firestore().collection("users")
            .where("roomId", "==", deviceId)
            .limit(1)
            .get();

        // Fallback: Check 'flatNumber' or 'flatNo' if deviceId is something like 'room101'
        let finalSnap = userQuery;
        if (userQuery.empty) {
            const roomNum = deviceId.replace("room", ""); // Extract '101' from 'room101'
            finalSnap = await admin.firestore().collection("users")
                .where("flatNumber", "==", roomNum)
                .limit(1)
                .get();
        }

        if (!finalSnap.empty) {
            const uDoc = finalSnap.docs[0];
            const u = uDoc.data();
            residentId = uDoc.id;
            residentData = {
                name: u.username || u.name || "Unknown Resident",
                flat: u.flatNumber || u.flatNo || "Unknown",
                building: u.buildingNumber || u.buildingNo || "Unknown",
                block: u.block || "Unknown",
                phone: u.phone || "Unknown"
            };
        }
    } catch (e) {
        console.error("Lookup error:", e);
    }

    // Create security_request (Triggers immediate Siren FCM via onSecurityRequestCreated)
    try {
        await admin.firestore().collection("security_requests").add({
            requestType: "smoke_alert",
            deviceId: deviceId,
            smokeType: smokeType,
            smokePpm: smokePpm,
            gasPpm: gasPpm,
            residentId: residentId,
            residentName: residentData.name,
            flatNumber: residentData.flat,
            buildingNumber: residentData.building,
            block: residentData.block,
            phone: residentData.phone,
            status: "pending",
            priority: "urgent",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Fast security_request created for ${deviceId}`);
    } catch (e) {
        console.error("Error creating fast alert:", e);
    }
});

/**
 * OPTIMIZED: Global Notification Trigger via Realtime Database.
 * Processes all generic app notifications with sub-second speed.
 */
exports.onNotificationRequestedRTDB = onValueUpdated("/notification_requests/{requestId}", async (event) => {
    const data = event.data.after.val();
    if (!data) return;

    const title = data.title || "New Message";
    const body = data.body || "You have a new notification.";
    const type = data.type || "general";
    const priority = (data.priority || "normal").toLowerCase();
    const toUid = data.toUid;
    const toRole = data.toRole;

    console.log(`⚡ FAST NOTIF: Processing ${type} request for ${toUid || toRole}`);

    const payload = {
        data: {
            title: title,
            body: body,
            type: String(type),
            priority: String(priority),
            toRole: String(toRole || ''),
            toUid: String(toUid || ''),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            ttl: 0,
        },
        apns: {
            payload: {
                aps: {
                    contentAvailable: true,
                    sound: priority === 'urgent' ? "urgent_alarm.aiff" : "default",
                    badge: 1,
                    alert: { title: title, body: body }
                },
            },
        }
    };

    try {
        if (toRole) {
            let topicCondition = "";
            if (toRole === "security") topicCondition = "'security' in topics";
            else if (toRole === "authority") topicCondition = "'authority' in topics";
            else if (toRole === "worker") topicCondition = "'worker' in topics";
            else if (toRole === "resident" || toRole === "user") topicCondition = "'resident' in topics || 'user' in topics";

            if (topicCondition) {
                payload.condition = topicCondition;
                await admin.messaging().send(payload);
            }
        } else if (toUid) {
            // High-speed token lookup
            const getTokens = async (coll) => {
                const doc = await admin.firestore().collection(coll).doc(toUid).get();
                return doc.exists ? doc.data().fcmToken : null;
            };

            const token = await getTokens("users") || await getTokens("workers") || await getTokens("authorities");

            if (token) {
                payload.token = token;
                await admin.messaging().send(payload);
            }
        }

        // Cleanup the request from RTDB after processing
        await event.data.after.ref.remove();

    } catch (e) {
        console.error("Error in fast notification dispatch:", e);
    }
});
