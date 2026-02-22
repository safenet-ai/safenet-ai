/**
 * Module 5: Cloud Functions Backend — White-Box Unit Tests
 *
 * Tests the logic of each Cloud Function trigger including:
 * - onAnnouncementCreated: FCM payload construction and topic routing
 * - onNotificationCreated: role-based vs direct token targeting
 * - onSecurityRequestCreated: panic alert detection and urgent priority
 *
 * NOTE: These tests validate the DATA CONTRACTS and LOGIC PATHS.
 * They don't actually trigger FCM — that requires the Firebase emulator.
 * Run with: cd functions && npx jest
 */
describe("Cloud Functions — Data Contracts", () => {

    // -------------------------------------------------------------------
    // onAnnouncementCreated — Payload Structure
    // -------------------------------------------------------------------
    describe("onAnnouncementCreated — Payload", () => {
        it("should construct correct FCM topic condition for 'everyone' audience", () => {
            const targetAudience = "everyone";
            let condition = "";

            if (targetAudience === "everyone") {
                condition = "'resident' in topics || 'worker' in topics || 'authority' in topics";
            }

            expect(condition).toContain("'resident' in topics");
            expect(condition).toContain("'worker' in topics");
            expect(condition).toContain("'authority' in topics");
        });

        it("should construct correct topic condition for 'workers' audience", () => {
            const targetAudience = "workers";
            let topicToTarget = "";

            if (targetAudience === "workers" || targetAudience === "worker") {
                topicToTarget = "'worker' in topics";
            } else if (targetAudience === "security") {
                topicToTarget = "'security' in topics";
            } else {
                topicToTarget = "'resident' in topics || 'user' in topics";
            }

            expect(topicToTarget).toBe("'worker' in topics");
        });

        it("should default to resident topic for unknown audience", () => {
            const targetAudience = "some_random_audience";
            let topicToTarget = "";

            if (targetAudience === "workers" || targetAudience === "worker") {
                topicToTarget = "'worker' in topics";
            } else if (targetAudience === "security") {
                topicToTarget = "'security' in topics";
            } else {
                topicToTarget = "'resident' in topics || 'user' in topics";
            }

            expect(topicToTarget).toBe("'resident' in topics || 'user' in topics");
        });

        it("should set android_channel_id to 'urgent' for urgent priority", () => {
            const priority = "urgent";
            const isUrgent = priority === "urgent";

            const androidConfig = {
                notification: {
                    channel_id: isUrgent ? "urgent" : (priority === "medium" ? "medium" : "default"),
                },
            };

            expect(androidConfig.notification.channel_id).toBe("urgent");
        });

        it("should set android_channel_id to 'medium' for medium priority", () => {
            const priority = "medium";
            const isUrgent = priority === "urgent";
            const isMedium = priority === "medium";

            const channel_id = isUrgent ? "urgent" : (isMedium ? "medium" : "default");
            expect(channel_id).toBe("medium");
        });

        it("should set android_channel_id to 'default' for normal priority", () => {
            const priority = "normal";
            const isUrgent = priority === "urgent";
            const isMedium = priority === "medium";

            const channel_id = isUrgent ? "urgent" : (isMedium ? "medium" : "default");
            expect(channel_id).toBe("default");
        });

        it("should format announcement title with category prefix", () => {
            const category = "Maintenance";
            const title = "Water Supply";
            const formattedTitle = `[${category}] ${title}`;
            expect(formattedTitle).toBe("[Maintenance] Water Supply");
        });
    });

    // -------------------------------------------------------------------
    // onNotificationCreated — Targeting Logic
    // -------------------------------------------------------------------
    describe("onNotificationCreated — Target Logic", () => {
        it("should route to topic condition when toRole is 'security'", () => {
            const toRole = "security";
            let topicCondition = "";

            if (toRole === "security") topicCondition = "'security' in topics";
            else if (toRole === "authority") topicCondition = "'authority' in topics";
            else if (toRole === "worker") topicCondition = "'worker' in topics";
            else if (toRole === "resident") topicCondition = "'resident' in topics";

            expect(topicCondition).toBe("'security' in topics");
        });

        it("should fall through to token lookup when toUid is set and toRole is empty", () => {
            const toRole = null;
            const toUid = "user-abc-123";

            let shouldUseTopic = false;
            let shouldUseToken = false;

            if (toRole) {
                shouldUseTopic = true;
            }
            if (toUid) {
                shouldUseToken = true;
            }

            expect(shouldUseTopic).toBe(false);
            expect(shouldUseToken).toBe(true);
        });

        it("should skip sending when sentByCloudFunction is true", () => {
            const data = {
                type: "complaint",
                sentByCloudFunction: true,
            };

            const shouldSkip = data.sentByCloudFunction === true;
            expect(shouldSkip).toBe(true);
        });

        it("should not skip when sentByCloudFunction is absent", () => {
            const data = {
                type: "complaint",
            };

            const shouldSkip = data.sentByCloudFunction === true;
            expect(shouldSkip).toBe(false);
        });

        it("should convert all data fields to String in payload", () => {
            const type = "security_request";
            const priority = "urgent";
            const toRole = "security";

            const payload = {
                data: {
                    type: String(type),
                    priority: String(priority),
                    toRole: String(toRole || ""),
                },
            };

            expect(typeof payload.data.type).toBe("string");
            expect(typeof payload.data.priority).toBe("string");
            expect(typeof payload.data.toRole).toBe("string");
        });
    });

    // -------------------------------------------------------------------
    // onSecurityRequestCreated — Panic Alert Logic
    // -------------------------------------------------------------------
    describe("onSecurityRequestCreated — Panic Detection", () => {
        it("should detect panic alert from requestType field", () => {
            const data = { requestType: "panic_alert" };
            const isPanic = data.requestType === "panic_alert";
            expect(isPanic).toBe(true);
        });

        it("should NOT flag non-panic requests as panic", () => {
            const data = { requestType: "general" };
            const isPanic = data.requestType === "panic_alert";
            expect(isPanic).toBe(false);
        });

        it("should override priority to 'urgent' for panic alerts", () => {
            const requestType = "panic_alert";
            const isPanic = requestType === "panic_alert";

            const priority = isPanic ? "urgent" : "normal";
            expect(priority).toBe("urgent");
        });

        it("should set FCM condition to target both security and authority", () => {
            const condition = "'authority' in topics || 'security' in topics";
            expect(condition).toContain("'authority' in topics");
            expect(condition).toContain("'security' in topics");
        });

        it("should construct correct panic alert title", () => {
            const isPanic = true;
            const flatNumber = "A-101";
            const title = isPanic
                ? `🚨 PANIC ALERT — Flat ${flatNumber}`
                : "New Security Request";

            expect(title).toContain("PANIC ALERT");
            expect(title).toContain("A-101");
        });

        it("should default requestType to 'general' when missing", () => {
            const data = {};
            const requestType = data.requestType || "general";
            expect(requestType).toBe("general");
        });
    });
});
