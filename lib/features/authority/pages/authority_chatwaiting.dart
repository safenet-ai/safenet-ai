import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './authority_chat.dart';
import '../../../services/notification_service.dart';

class AuthorityWaitingListPage extends StatefulWidget {
  const AuthorityWaitingListPage({super.key});

  @override
  State<AuthorityWaitingListPage> createState() =>
      _AuthorityWaitingListPageState();
}

class _AuthorityWaitingListPageState extends State<AuthorityWaitingListPage> {
  final StreamController<List<Map<String, dynamic>>> _combinedStream =
      StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    _listenToCombinedRequests();
  }

  void _listenToCombinedRequests() {
    QuerySnapshot? residentWaitingCache;
    QuerySnapshot? residentActiveCache;
    QuerySnapshot? workerWaitingCache;
    QuerySnapshot? workerActiveCache;
    QuerySnapshot? securityWaitingCache;
    QuerySnapshot? securityActiveCache;

    void combineAndEmit() {
      List<Map<String, dynamic>> combined = [];

      // Add waiting residents
      if (residentWaitingCache != null) {
        for (var doc in residentWaitingCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["residentName"] ?? "Resident",
            "type": "resident",
            "status": "waiting",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Add active residents
      if (residentActiveCache != null) {
        for (var doc in residentActiveCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["residentName"] ?? "Resident",
            "type": "resident",
            "status": "active",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Add waiting workers
      if (workerWaitingCache != null) {
        for (var doc in workerWaitingCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["workerName"] ?? "Worker",
            "type": "worker",
            "status": "waiting",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Add active workers
      if (workerActiveCache != null) {
        for (var doc in workerActiveCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["workerName"] ?? "Worker",
            "type": "worker",
            "status": "active",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Add waiting security
      if (securityWaitingCache != null) {
        for (var doc in securityWaitingCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["securityName"] ?? "Security",
            "type": "security",
            "status": "waiting",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Add active security
      if (securityActiveCache != null) {
        for (var doc in securityActiveCache!.docs) {
          combined.add({
            "id": doc.id,
            "name": doc["securityName"] ?? "Security",
            "type": "security",
            "status": "active",
            "createdAt": doc["createdAt"],
          });
        }
      }

      // Sort: Active first, then by createdAt
      combined.sort((a, b) {
        // Active comes before waiting
        if (a["status"] == "active" && b["status"] == "waiting") return -1;
        if (a["status"] == "waiting" && b["status"] == "active") return 1;

        final aTime = a["createdAt"] as Timestamp?;
        final bTime = b["createdAt"] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      _combinedStream.add(combined);
    }

    // Listen to waiting resident requests
    FirebaseFirestore.instance
        .collection("support_requests")
        .where("status", isEqualTo: "waiting")
        .snapshots()
        .listen(
          (snapshot) {
            print("Resident waiting requests: ${snapshot.docs.length}");
            residentWaitingCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to resident requests: $error");
          },
        );

    // Listen to active resident requests
    FirebaseFirestore.instance
        .collection("support_requests")
        .where("status", isEqualTo: "active")
        .snapshots()
        .listen(
          (snapshot) {
            print("Resident active requests: ${snapshot.docs.length}");
            residentActiveCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to active resident requests: $error");
          },
        );

    // Listen to waiting worker requests
    FirebaseFirestore.instance
        .collection("worker_support_requests")
        .where("status", isEqualTo: "waiting")
        .snapshots()
        .listen(
          (snapshot) {
            print("Worker waiting requests: ${snapshot.docs.length}");
            workerWaitingCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to worker requests: $error");
          },
        );

    // Listen to active worker requests
    FirebaseFirestore.instance
        .collection("worker_support_requests")
        .where("status", isEqualTo: "active")
        .snapshots()
        .listen(
          (snapshot) {
            print("Worker active requests: ${snapshot.docs.length}");
            workerActiveCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to active worker requests: $error");
          },
        );

    // Listen to waiting security requests
    FirebaseFirestore.instance
        .collection("security_support_requests")
        .where("status", isEqualTo: "waiting")
        .snapshots()
        .listen(
          (snapshot) {
            print("Security waiting requests: ${snapshot.docs.length}");
            securityWaitingCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to security requests: $error");
          },
        );

    // Listen to active security requests
    FirebaseFirestore.instance
        .collection("security_support_requests")
        .where("status", isEqualTo: "active")
        .snapshots()
        .listen(
          (snapshot) {
            print("Security active requests: ${snapshot.docs.length}");
            securityActiveCache = snapshot;
            combineAndEmit();
          },
          onError: (error) {
            print("Error listening to active security requests: $error");
          },
        );
  }

  @override
  void dispose() {
    _combinedStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Background
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ✅ TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),

                      const Text(
                        "Support Requests",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      _circleButton(Icons.headset_mic),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ STATUS CHIP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Support Requests",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ COMBINED WAITING LIST (RESIDENTS + WORKERS)
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _combinedStream.stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            "No support requests waiting right now",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      }

                      final requests = snapshot.data!;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];

                          return _waitingCard(
                            name: request["name"],
                            docId: request["id"],
                            type: request["type"],
                            status: request["status"],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ WAITING/ACTIVE CARD
  Widget _waitingCard({
    required String name,
    required String docId,
    required String type,
    required String status,
  }) {
    final bool isWorker = type == "worker";
    final bool isSecurity = type == "security";
    final bool isActive = status == "active";
    final String collection = isWorker
        ? "worker_support_requests"
        : isSecurity
        ? "security_support_requests"
        : "support_requests";

    return GestureDetector(
      onTap: () async {
        // ✅ MARK AS ACTIVE (only if waiting)
        if (!isActive) {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(docId)
              .update({"status": "active"});

          // Send notification based on type
          try {
            final requestDoc = await FirebaseFirestore.instance
                .collection(collection)
                .doc(docId)
                .get();

            String? targetUid;
            String targetRole;
            
            if (isWorker) {
              targetUid = requestDoc.data()?["workerId"];
              targetRole = 'worker';
            } else if (isSecurity) {
              targetUid = requestDoc.data()?["securityId"];
              targetRole = 'security';
            } else {
              targetUid = requestDoc.data()?["residentId"];
              targetRole = 'user';
            }

            if (targetUid != null) {
              await NotificationService.sendNotification(
                userId: targetUid,
                userRole: targetRole,
                title: 'Authority Connected',
                body: 'Authority has joined your chat. You can now talk with them.',
                type: 'chat_connected',
                additionalData: {'conversationId': docId},
              );
              print("✅ Notification sent to $targetRole: $targetUid");
            }
          } catch (e) {
            print("⚠️ Error sending notification for $type: $e");
          }
        }

        // ✅ OPEN AUTHORITY CHAT
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuthorityChatPage(
              conversationId: docId,
              userName: name,
              userType: type,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.90),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isWorker
                    ? const Color(0xFFE7DFFC)
                    : isSecurity
                    ? const Color(0xFFFFE5B4)
                    : const Color(0xFF6EA7A0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWorker
                    ? Icons.engineering
                    : isSecurity
                    ? Icons.security
                    : Icons.person,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            // Name and Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isWorker
                        ? "Worker"
                        : isSecurity
                        ? "Security"
                        : "Resident",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isActive ? "ACTIVE" : "WAITING",
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ CIRCLE BUTTON
  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
