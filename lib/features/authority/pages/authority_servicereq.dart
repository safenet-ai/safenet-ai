import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                  const Text(
                    "Service Details",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 24),
              if (data["status"] == "Pending")
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Check if resident already selected a worker
                      if (data["assignedWorker"] != null) {
                        await _assignWorkerDirectly(context, docId, data);
                      } else {
                        _showWorkerSelection(context, docId, data);
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text("Assign Worker"),
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
      await FirebaseFirestore.instance
          .collection("service_requests")
          .doc(serviceDocId)
          .update({
            "assignedWorker": {
              "id": workerId,
              "name": workerName,
              "role": workerProfession,
            },
            "status": "Assigned",
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

  /// ✅ FIRESTORE SERVICE REQUESTS
  Widget _firestoreList(String filter) {
    Query query = FirebaseFirestore.instance.collection("service_requests");

    if (filter == "In Progress") {
      // Show requests that are Assigned and have been started
      query = query
          .where("status", isEqualTo: "Assigned")
          .where("isStarted", isEqualTo: true);
    } else if (filter == "Assigned") {
      // Show only assigned but not started
      query = query
          .where("status", isEqualTo: "Assigned")
          .where("isStarted", isEqualTo: false);
    } else if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // For "Assigned" filter, also filter out null isStarted
        List<QueryDocumentSnapshot> filteredDocs = docs;
        if (filter == "Assigned") {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data["isStarted"] != true;
          }).toList();
        }

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No service requests found"));
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final docId = filteredDocs[index].id;

            return GestureDetector(
              onTap: () => _showServiceDetails(context, docId, data),
              child: _serviceCard(
                id: data["service_id"],
                name: data["username"],
                category: data["category"],
                date: _formatDate(data["timestamp"]),
                status:
                    data["status"] == "Assigned" && data["isStarted"] == true
                    ? "In Progress"
                    : data["status"],
                worker: data["assignedWorker"] != null
                    ? data["assignedWorker"]["name"]
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ SERVICE REQUEST CARD (EXACT UI FROM IMAGE)
  Widget _serviceCard({
    required String id,
    required String name,
    required String category,
    required String date,
    required String status,
    String? worker,
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
