import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'servicerequest.dart';
import 'widget/profile_sidebar.dart';
import 'widget/filter_tabs.dart';
import 'widget/notification_dropdown.dart';

class ServiceRequestpage extends StatefulWidget {
  const ServiceRequestpage({super.key});

  @override
  State<ServiceRequestpage> createState() => _ServiceRequestpageState();
}

class _ServiceRequestpageState extends State<ServiceRequestpage> {
  bool _isProfileOpen = false;

  String selectedFilter = "All";
  final PageController _pageController = PageController();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- FIXED TOP BAR (NON-SCROLL) ----------
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _circleIcon(Icons.arrow_back),
                      ),
                      Row(
                        children: [
                          NotificationDropdown(role: "user"),

                          const SizedBox(width: 15),

                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleIcon(Icons.person),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---------- SCROLLABLE BODY BELOW ----------
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 50),

                          const Text(
                            "Service Requests",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 83, 83, 83),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // + New Service Request Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const NewServiceRequestpage(),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    117,
                                    213,
                                    251,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12.withOpacity(0.20),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "+ New Service Request",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 50),

                          // ---------- FILTER TABS (COMPLAINT STYLE) ----------
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FilterTabs(
                              selected: selectedFilter,
                              tabs: [
                                FilterTabItem("All", Icons.apps),
                                FilterTabItem("Pending", Icons.access_time),
                                FilterTabItem("Assigned", Icons.work),
                                FilterTabItem("Completed", Icons.check),
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

                          // ---------- PAGEVIEW WITH STREAM ----------
                          SizedBox(
                            height: 500,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  selectedFilter = [
                                    "All",
                                    "Pending",
                                    "Assigned",
                                    "Completed",
                                  ][index];
                                });
                              },
                              children: [
                                _requestList("All"),
                                _requestList("Pending"),
                                _requestList("Assigned"),
                                _requestList("Completed"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Center(
                            child: Text(
                              "Check the status of your Requests",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                userCollection: "users",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // CIRCLE ICON (PURE WHITE BACKGROUND)
  Widget _circleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white70, // ✅ PURE WHITE BACKGROUND
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12, // ✅ soft shadow
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black87, size: 22),
    );
  }

  void _showServiceDetails(BuildContext context, Map<String, dynamic> data) {
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
                    "Service Request Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow("Service ID", data["service_id"] ?? "N/A"),
              _detailRow("Title", data["title"] ?? "N/A"),
              _detailRow("Category", data["category"] ?? "N/A"),
              _detailRow("Status", data["status"] ?? "N/A"),
              _detailRow(
                "Date",
                data["timestamp"] != null
                    ? _formatTimestamp(data["timestamp"])
                    : "N/A",
              ),
              _detailRow(
                "Assigned Worker",
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
              if (data["files"] != null &&
                  (data["files"] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "Attachments:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    (data["files"] as List).length,
                    (index) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data["files"][index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.day} ${_month(date.month)} ${date.year}";
  }

  // Request List
  Widget _requestList(String filter) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("User not logged in"));
    }

    Query query = FirebaseFirestore.instance
        .collection("service_requests")
        .where("userId", isEqualTo: user.uid);

    if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy("timestamp", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No service requests found"));
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          //shrinkWrap: true,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final Timestamp ts = data["timestamp"];
            final DateTime date = ts.toDate();
            final formattedDate =
                "${date.day} ${_month(date.month)} ${date.year}";

            return GestureDetector(
              onTap: () => _showServiceDetails(context, data),
              child: _requestCard(
                serviceId: data["service_id"], // ✅ IMPORTANT
                title: data["title"],
                desc: data["description"],
                date: formattedDate,
                status: data["status"],
              ),
            );
          },
        );
      },
    );
  }

  String _month(int m) {
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
    return months[m - 1];
  }

  // Request Card (FINAL FIXED STATUS STYLE)
  Widget _requestCard({
    required String serviceId,
    required String title,
    required String date,
    required String desc,
    required String status,
  }) {
    Color statusColor = status == "Pending"
        ? const Color(0xFFFFE680)
        : status == "Assigned"
        ? const Color(0xFFBBD9FF)
        : const Color(0xFFBBF3C1);

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.88,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceId, // ✅ SRVC-1001
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                date,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
