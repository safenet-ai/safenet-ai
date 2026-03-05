import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../../services/notification_service.dart';

class AuthorityWaterSupplyPage extends StatefulWidget {
  const AuthorityWaterSupplyPage({super.key});

  @override
  State<AuthorityWaterSupplyPage> createState() =>
      _AuthorityWaterSupplyPageState();
}

class _AuthorityWaterSupplyPageState extends State<AuthorityWaterSupplyPage> {
  String selectedFilter = "All";
  bool _isProfileOpen = false;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // ─── Header ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIcon(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        "SafeNet AI",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          const NotificationDropdown(role: "authority"),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => setState(() => _isProfileOpen = true),
                            child: _circleIcon(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ─── Title ───
                  const Text(
                    "Water Supply",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    "Orders",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Filter tabs ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FilterTabs(
                      selected: selectedFilter,
                      tabs: [
                        FilterTabItem("All", Icons.apps),
                        FilterTabItem("Pending", Icons.access_time),
                        FilterTabItem("Delivered", Icons.check_circle),
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

                  const SizedBox(height: 20),

                  // ─── List ───
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          selectedFilter = [
                            "All",
                            "Pending",
                            "Delivered",
                          ][index];
                        });
                      },
                      children: [
                        _orderList("All"),
                        _orderList("Pending"),
                        _orderList("Delivered"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Profile sidebar overlay ───
          if (_isProfileOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isProfileOpen = false),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
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

  // ──────────────────────────────────────────────
  //  Firestore list per filter
  // ──────────────────────────────────────────────
  Widget _orderList(String filter) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "water_orders",
    );

    if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy("timestamp", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 56,
                  color: Colors.blueGrey.shade200,
                ),
                const SizedBox(height: 12),
                Text(
                  filter == "All"
                      ? "No water orders yet."
                      : "No $filter orders.",
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            return _orderCard(context, docs[i].id, docs[i].data());
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  Order card
  // ──────────────────────────────────────────────
  Widget _orderCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final status = data["status"] ?? "Pending";
    final Color statusColor = status == "Delivered"
        ? const Color(0xFFBBF3C1)
        : const Color(0xFFFFE680);

    final scheduledDate = data["scheduledDate"] != null
        ? (data["scheduledDate"] as Timestamp).toDate()
        : null;

    final workerName = (data["assignedWorker"] is Map)
        ? (data["assignedWorker"] as Map)["name"] ?? "N/A"
        : data["assignedWorker"]?.toString() ?? "N/A";

    return GestureDetector(
      onTap: () => _showOrderDetails(context, docId, data),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.92,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Row: ID + status chip ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data["orderId"] ?? "N/A",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ─── Water type + qty ───
                Text(
                  "${data["type"] ?? "Unknown"} × ${data["quantity"] ?? 1}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                // ─── Scheduled date ───
                if (scheduledDate != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Scheduled: ${DateFormat('EEE, MMM d, yyyy').format(scheduledDate)}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 6),

                // ─── Supplier ───
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Supplier: $workerName",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Order detail dialog
  // ──────────────────────────────────────────────
  void _showOrderDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final status = data["status"] ?? "Pending";
    final scheduledDate = data["scheduledDate"] != null
        ? (data["scheduledDate"] as Timestamp).toDate()
        : null;
    final workerMap = data["assignedWorker"] is Map
        ? data["assignedWorker"] as Map
        : <String, dynamic>{};
    final workerName = workerMap["name"]?.toString() ?? "N/A";
    final workerId = workerMap["id"]?.toString();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.97),
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
                    "Water Order Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _detailRow("Order ID", data["orderId"] ?? "N/A"),
              _detailRow("Type", data["type"] ?? "N/A"),
              _detailRow("Quantity", "${data["quantity"] ?? 1}"),
              _detailRow("Status", status),
              _detailRow(
                "Scheduled",
                scheduledDate != null
                    ? DateFormat('EEE, MMM d, yyyy').format(scheduledDate)
                    : "N/A",
              ),
              _detailRow("Supplier", workerName),
              _detailRow(
                "Ordered On",
                data["timestamp"] != null
                    ? _formatTs(data["timestamp"])
                    : "N/A",
              ),

              const SizedBox(height: 20),

              // ─── Mark as Delivered button ───
              if (status == "Pending")
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _markDelivered(docId, data, workerId);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Mark as Delivered"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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

  // ──────────────────────────────────────────────
  //  Mark order as Delivered + notify resident
  // ──────────────────────────────────────────────
  Future<void> _markDelivered(
    String docId,
    Map<String, dynamic> data,
    String? workerId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection("water_orders")
          .doc(docId)
          .update({"status": "Delivered"});

      final residentUid = data["userId"] as String?;
      final orderId = data["orderId"] ?? docId;
      final type = data["type"] ?? "water";

      // Notify the resident
      if (residentUid != null) {
        NotificationService.sendNotification(
          userId: residentUid,
          userRole: 'resident',
          title: '💧 Water Order Delivered',
          body: 'Your $type order ($orderId) has been delivered.',
          type: 'water_order_delivered',
          additionalData: {'orderId': docId},
        );
      }

      // Notify the supplier worker
      if (workerId != null) {
        NotificationService.sendNotification(
          userId: workerId,
          userRole: 'worker',
          title: 'Order Completed',
          body: 'Water order $orderId has been marked as delivered.',
          type: 'water_order_delivered',
          additionalData: {'orderId': docId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order marked as Delivered.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ──────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Widget _circleIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}
