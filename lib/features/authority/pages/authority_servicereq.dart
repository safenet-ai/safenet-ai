import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/profile_sidebar.dart';

class AuthorityServiceManagementPage extends StatefulWidget {
  const AuthorityServiceManagementPage({super.key});

  @override
  State<AuthorityServiceManagementPage> createState() =>
      _AuthorityServiceManagementPageState();
}

class _AuthorityServiceManagementPageState
    extends State<AuthorityServiceManagementPage> {
  String selectedFilter = "All";
  bool _isProfileOpen = false;
  final PageController _pageController = PageController();

  Future<void> _showServiceDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final isWater = data["_type"] == "water";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isWater ? "Order Details" : "Service Details",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isWater) ...[
                _detailRow("Order ID", data["orderId"] ?? "N/A"),
                _detailRow("User ID", data["userId"] ?? "N/A"), // Ideally fetch username
                _detailRow("Type", data["type"] ?? "N/A"),
                _detailRow("Quantity", "${data["quantity"] ?? 0}"),
                _detailRow("Status", data["status"] ?? "N/A"),
                _detailRow(
                  "Scheduled",
                   data["scheduledDate"] != null
                      ? _formatDate(data["scheduledDate"])
                      : "N/A",
                ),
                _detailRow(
                  "Worker",
                  data["assignedWorker"] != null
                      ? data["assignedWorker"]["name"]
                      : "Not Assigned",
                ),
              ] else ...[
                _detailRow("Service ID", data["service_id"] ?? "N/A"),
                _detailRow("Resident", data["username"] ?? "N/A"),
                _detailRow("Category", data["category"] ?? "N/A"),
                _detailRow("Status", data["status"] ?? "N/A"),
                _detailRow(
                  "Date",
                  data["timestamp"] != null
                      ? _formatDate(data["timestamp"])
                      : "N/A",
                ),
                _detailRow(
                  "Worker",
                  data["assignedWorker"] != null
                      ? data["assignedWorker"]["name"]
                      : "Not Assigned",
                ),
                const SizedBox(height: 12),
                const Text(
                  "Description:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  data["description"] ?? "No description provided",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
              
              const SizedBox(height: 24),
              // Only allow assigning if Pending (and mostly for services, but water can be reassigned if needed)
              // Water orders usually come with worker pre-selected by user, but if status is Pending and no worker?
              // Current flow: User picks worker. So assignedWorker should be there.
              // If we want Authority to assign/reassign, we can enable this. 
              // For now, let's keep it simple: allow assignment if Pending and no worker.
              // Only allow assigning if Pending (and mostly for services, but water can be reassigned if needed)
              // Water orders usually come with worker pre-selected by user.
              // User requested to remove "Confirm Assignment".
              // So if it's a water order and already has a worker, we hide the button.
              // For other services, we keep the logic to allow confirmation or assignment.
              if (data["status"] == "Pending" && (!isWater || data["assignedWorker"] == null))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Check if resident already selected a worker
                      if (data["assignedWorker"] != null) {
                         // If already assigned (e.g. by resident), maybe show "Reassign"? 
                         // Or just confirm assignment? 
                         // Actually _assignWorkerDirectly just updates status to Assigned.
                         // For water, we might just want to confirm it? 
                         // But water orders go to worker directly. 
                         // Let's allow authority to override or confirm.
                        await _assignWorkerDirectly(context, docId, data);
                      } else {
                        _showWorkerSelection(context, docId, data);
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: Text(data["assignedWorker"] != null ? "Confirm Assignment" : "Assign Worker"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7DD3C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkerSelection(
    BuildContext context,
    String docId,
    Map<String, dynamic> serviceData,
  ) async {
    final category = serviceData["category"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Select Worker",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: category != null && category.toString().isNotEmpty
                      ? FirebaseFirestore.instance
                            .collection("workers")
                            .where("isActive", isEqualTo: true)
                            .where("profession", isEqualTo: category)
                            .snapshots()
                      : FirebaseFirestore.instance
                            .collection("workers")
                            .where("isActive", isEqualTo: true)
                            .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final workers = snapshot.data!.docs;

                    if (workers.isEmpty) {
                      return const Center(
                        child: Text("No workers available for this category"),
                      );
                    }

                    return ListView.separated(
                      controller: controller,
                      itemCount: workers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final worker =
                            workers[index].data() as Map<String, dynamic>;
                        final workerId = workers[index].id;

                        return GestureDetector(
                          onTap: () async {
                            await _assignWorker(
                              docId,
                              workerId,
                              worker["username"],
                              worker["profession"],
                              serviceData,
                            );
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blueGrey,
                                  child: Text(
                                    worker["username"]
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        worker["username"] ?? "Worker",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        worker["profession"] ?? "",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assignWorkerDirectly(
    BuildContext context,
    String serviceDocId,
    Map<String, dynamic> serviceData,
  ) async {
    final workerData = serviceData["assignedWorker"] as Map<String, dynamic>;

    await _assignWorker(
      serviceDocId,
      workerData["id"],
      workerData["name"],
      workerData["role"] ?? "",
      serviceData,
    );
  }

  Future<void> _assignWorker(
    String serviceDocId,
    String workerId,
    String workerName,
    String workerProfession,
    Map<String, dynamic> serviceData,
  ) async {
    try {

      final isWater = serviceData["_type"] == "water";
      final collection = isWater ? "water_orders" : "service_requests";

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(serviceDocId)
          .update({
            "assignedWorker": {
              "id": workerId,
              "name": workerName,
              "role": workerProfession,
            },
            "status": isWater ? "Out for Delivery" : "Assigned", // Update status for water if needed, or keep "Assigned" if that's the convention. 
                                                                 // Actually water flow usually: Pending -> Out for Delivery.
                                                                 // Let's set to "Out for Delivery" if assigned? 
                                                                 // Or just "Assigned" if we want to track it that way.
                                                                 // Worker dashboard looks for "Out for Delivery".
                                                                 // Let's us "Out for Delivery" for water.
          });

      // Send notification to worker
      await FirebaseFirestore.instance.collection("notifications").add({
        "title": "New Service Assigned",
        "message":
            "You have been assigned to service: ${serviceData["title"] ?? serviceData["category"]}",
        "toUid": workerId,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Send notification to resident
      await FirebaseFirestore.instance.collection("notifications").add({
        "title": "Worker Assigned",
        "message":
            "Worker $workerName has been assigned to your service request",
        "toUid": serviceData["userId"],
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Worker $workerName assigned successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error assigning worker: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ✅ FIXED TOP BAR
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIcon(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Service Management",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          _circleIcon(Icons.notifications_none_rounded),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleIcon(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  /// ✅ SCROLLABLE BODY
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 35),

                          const Text(
                            "Service Requests",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 40),

                          /// ✅ FILTER TABS - SCROLLABLE
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FilterTabs(
                              selected: selectedFilter,
                              tabs: [
                                FilterTabItem("All", Icons.apps),
                                FilterTabItem("Pending", Icons.access_time),
                                FilterTabItem("Assigned", Icons.work),
                                FilterTabItem("In Progress", Icons.build),
                                FilterTabItem("Completed", Icons.check_circle),
                              ],
                              onChanged: (index, label) {
                                setState(() => selectedFilter = label);
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            height: 450,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  selectedFilter = switch (index) {
                                    0 => "All",
                                    1 => "Pending",
                                    2 => "Assigned",
                                    3 => "In Progress",
                                    _ => "Completed",
                                  };
                                });
                              },
                              children: [
                                _firestoreList("All"),
                                _firestoreList("Pending"),
                                _firestoreList("Assigned"),
                                _firestoreList("In Progress"),
                                _firestoreList("Completed"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Center(
                            child: Text(
                              "Slide between tabs to manage requests efficiently.",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isProfileOpen) ...[
            // Dark blur background
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isProfileOpen = false),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),

            // Sliding profile panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              right: 0,
              width: 280,
              child: ProfileSidebar(
                onClose: () => setState(() => _isProfileOpen = false),
                userCollection: "authority",
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ✅ FIRESTORE SERVICE REQUESTS & WATER ORDERS
  Widget _firestoreList(String filter) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCombinedRequestsStream(filter),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return const Center(child: Text("No requests found"));
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final data = requests[index];
            final docId = data["_docId"];
            final isWater = data["_type"] == "water";

            return GestureDetector(
              onTap: () => _showServiceDetails(context, docId, data),
              child: _serviceCard(
                id: isWater ? (data["orderId"] ?? "N/A") : (data["service_id"] ?? "N/A"),
                name: data["username"] ?? (isWater ? "Resident" : "Unknown"), // Water orders might use userId, ensure username is fetched or available
                category: isWater ? "Water Supply" : (data["category"] ?? "N/A"),
                date: _formatDate(data["timestamp"]),
                status: (filter == "In Progress" || (data["status"] == "Assigned" && data["isStarted"] == true))
                        ? "In Progress"
                        : data["status"],
                worker: data["assignedWorker"] != null
                    ? data["assignedWorker"]["name"]
                    : null,
                isWater: isWater,
                subInfo: isWater ? "${data["type"]} - ${data["quantity"]}" : null,
              ),
            );
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getCombinedRequestsStream(String filter) {
    // This controller will emit the combined list
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    List<Map<String, dynamic>> serviceData = [];
    List<Map<String, dynamic>> waterData = [];

    // Helper to emit sorted combined list
    void emitCombined() {
      final combined = [...serviceData, ...waterData];
      combined.sort((a, b) {
        final tA = a["timestamp"] as Timestamp?;
        final tB = b["timestamp"] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA); // Newest first
      });
      if (!controller.isClosed) controller.add(combined);
    }

    // SERVICE REQUESTS QUERY
    Query serviceQuery = FirebaseFirestore.instance.collection("service_requests");
    if (filter == "In Progress") {
      serviceQuery = serviceQuery.where("status", isEqualTo: "Assigned").where("isStarted", isEqualTo: true);
    } else if (filter == "Assigned") {
      serviceQuery = serviceQuery.where("status", isEqualTo: "Assigned").where("isStarted", isEqualTo: false);
    } else if (filter != "All") {
      serviceQuery = serviceQuery.where("status", isEqualTo: filter);
    }

    // WATER ORDERS QUERY
    Query waterQuery = FirebaseFirestore.instance.collection("water_orders");
    // Map filters for water orders
    // Water orders status: Pending, Delivered (Completed), Out for Delivery 
    // We need to map "Assigned" -> "Pending" with worker assigned? Or maybe "Out for Delivery"?
    // Let's assume:
    // Pending -> Pending (no worker or worker assigned but not started?) 
    // Actually in WaterSupplyPage submit, we set status "Pending".
    // When worker is picked, it's still "Pending" but has assignedWorker.
    // Let's stick to status field.
    
    if (filter == "In Progress") {
       waterQuery = waterQuery.where("status", isEqualTo: "Out for Delivery");
    } else if (filter == "Assigned") {
       // Water orders don't exactly have "Assigned" status usually, they go Pending -> Out for Delivery -> Delivered
       // But if we want to show them, maybe we check if assignedWorker exists?
       // For now, let's just match status string if possible, or skip if not applicable
       // If the system uses "Assigned" for water, we'd query that. 
       // Based on `WaterSupplyPage`, status is initialized to "Pending".
       // Let's assume for now we only show matching status strings, plus "Out for Delivery" as "In Progress".
       waterQuery = waterQuery.where("status", isEqualTo: "Assigned"); // Placeholder if used
    } else if (filter == "Completed") {
       waterQuery = waterQuery.where("status", isEqualTo: "Delivered");
    } else if (filter != "All") {
       waterQuery = waterQuery.where("status", isEqualTo: filter);
    }

    // We might need to adjust logic if water orders use different status enum. 
    // Checking `WaterSupplyPage`: status = "Pending". 
    // Worker updates: `WorkerMyJobsPage` listens to Pending, Out for Delivery, Delivered.
    // So:
    // Pending -> Pending
    // Out for Delivery -> In Progress
    // Delivered -> Completed
    
    // override queries for simple mapping
    if (filter == "In Progress") {
       waterQuery = FirebaseFirestore.instance.collection("water_orders").where("status", isEqualTo: "Out for Delivery");
    } else if (filter == "Assigned") {
       // Start matches 'Pending' but with a worker? 
       // For simplicity, let's treat "Pending" with worker as "Assigned"? 
       // Or just ignore "Assigned" tab for water if it doesn't fit.
       // Let's just query strictly so we don't break things.
       waterQuery = FirebaseFirestore.instance.collection("water_orders").where("status", isEqualTo: "Assigned");
    }

    final serviceSub = serviceQuery.snapshots().listen((snapshot) {
      serviceData = snapshot.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data["_docId"] = d.id;
        data["_type"] = "service";
        return data;
      }).toList();
      // Filter locally for "Assigned" case in services (isStarted check)
      if (filter == "Assigned") {
         serviceData = serviceData.where((d) => d["isStarted"] != true).toList();
      }
      emitCombined();
    });

    final waterSub = waterQuery.snapshots().listen((snapshot) {
      waterData = snapshot.docs.map((d) {
         final data = d.data() as Map<String, dynamic>;
         data["_docId"] = d.id;
         data["_type"] = "water";
         // Retrieve username for water orders if missing?
         // Water orders have 'userId'. We might need to fetch user profile or store username in order.
         // For now, if username missing, we'll see.
         return data;
      }).toList();
      emitCombined();
    });

    controller.onCancel = () {
      serviceSub.cancel();
      waterSub.cancel();
    };

    return controller.stream;
  }

  /// ✅ SERVICE REQUEST CARD (EXACT UI FROM IMAGE)
  Widget _serviceCard({
    required String id,
    required String name,
    required String category,
    required String date,
    required String status,
    String? worker,
    bool isWater = false,
    String? subInfo,
  }) {
    Color statusColor = status == "Pending"
        ? const Color(0xFFFFE680)
        : status == "In Progress"
        ? const Color(0xFFFFB74D)
        : status == "Assigned"
        ? const Color(0xFFBEE7E8)
        : const Color(0xFFBBF3C1);

    String footerText = status == "Pending"
        ? "Awaiting worker assignment"
        : status == "In Progress"
        ? "Worker ${worker ?? ""} is working on this"
        : status == "Assigned"
        ? "Worker ${worker ?? ""} assigned"
        : "Work completed by Worker ${worker ?? ""}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.15),
              blurRadius: 2,
              offset: const Offset(4, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ✅ STATUS PILL TOP RIGHT
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ✅ LEFT SIDE DETAILS (STARTS FROM TOP)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rowItem("Req ID:", id),
                      _rowItem("Resident:", name),
                      _rowItem("Service Type:", category),
                      if (isWater && subInfo != null)
                        _rowItem("Details:", subInfo),
                      _rowItem("Worker:", worker ?? "-"),
                      _rowItem("Date:", date),
                    ],
                  ),
                ),

                /// ✅ STATUS PILL (RIGHT SIDE – SAME TOP LEVEL)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            /// ✅ FOOTER STATUS MESSAGE
            Text(
              footerText,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ CIRCLE ICON
  Widget _circleIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

/// ✅ DATE FORMATTER
String _formatDate(Timestamp timestamp) {
  final date = timestamp.toDate();
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return "${date.day} ${months[date.month - 1]} ${date.year}";
}
