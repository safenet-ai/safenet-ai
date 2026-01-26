import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widget/filter_tabs.dart';
import 'widget/profile_sidebar.dart';

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
                      _circleIcon(Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),
                      const Text(
                        "Service Management",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
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

                          /// ✅ FILTER TABS EXACTLY LIKE SERVICE REQUEST PAGE
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FilterTabs(
                              selected: selectedFilter,
                              tabs: [
                                FilterTabItem("All", Icons.apps),
                                FilterTabItem("Pending", Icons.access_time),
                                FilterTabItem("Assigned", Icons.work),
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
                                    _ => "Completed",
                                  };
                                });
                              },
                              children: [
                                _firestoreList("All"),
                                _firestoreList("Pending"),
                                _firestoreList("Assigned"),
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
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),

            // Sliding profile panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.33,
              child: ProfileSidebar(
                onClose: () => setState(() => _isProfileOpen = false),
                userCollection: "workers",
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

    if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No service requests found"));
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return _serviceCard(
              id: data["service_id"],
              name: data["username"],
              category: data["category"],
              date: _formatDate(data["timestamp"]),
              status: data["status"],
              worker: data["assignedWorker"] != null
                  ? data["assignedWorker"]["name"]
                  : null,
            );
          },
        );
      },
    );
  }

  /// ✅ SERVICE REQUEST CARD (EXACT UI FROM IMAGE)
  Widget _serviceCard(
    {
      required String id,
      required String name,
      required String category,
      required String date,
      required String status,
      String? worker,
   }
  ) 
  {
        Color statusColor = status == "Pending"
            ? const Color(0xFFFFE680)
            : status == "Assigned"
                ? const Color(0xFFBEE7E8)
                : const Color(0xFFBBF3C1);

        String footerText = status == "Pending"
            ? "Awaiting worker assignment"
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                /// ✅ FOOTER STATUS MESSAGE
                Text(
                  footerText,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black54),
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
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
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
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8),
          ],
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
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return "${date.day} ${months[date.month - 1]} ${date.year}";
}
