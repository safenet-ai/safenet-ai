import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widget/filter_tabs.dart';
import 'widget/profile_sidebar.dart';

class AuthorityComplaintsPage extends StatefulWidget {
  const AuthorityComplaintsPage({super.key});

  @override
  State<AuthorityComplaintsPage> createState() =>
      _AuthorityComplaintsPageState();
}

class _AuthorityComplaintsPageState extends State<AuthorityComplaintsPage> {
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

                  //  FIXED TOP BAR (NON-SCROLL)
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIcon(Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),
                      const Text(
                        "SafeNet AI",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                  //  EVERYTHING BELOW WILL SCROLL
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 35),

                          const Text(
                            "Complaint Management",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 40),

                          ///  FILTER TABS (NOW SCROLLABLE)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FilterTabs(
                              selected: selectedFilter,
                              tabs: [
                                FilterTabItem("All", Icons.apps),
                                FilterTabItem("Pending", Icons.access_time), 
                                FilterTabItem("In Progress", Icons.autorenew),
                                FilterTabItem("Resolved", Icons.check_circle),
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
                            height: 420, //  keeps layout stable
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  selectedFilter = switch (index) {
                                    0 => "All",
                                    1 => "Pending",
                                    2 => "In Progress",
                                    _ => "Resolved",
                                  };
                                });
                              },
                              children: [
                                _firestoreList("All"),
                                _firestoreList("Pending"),
                                _firestoreList("In Progress"),
                                _firestoreList("Resolved"),
                              ],

                            ),
                          ),

                          const SizedBox(height: 20),

                          const Center(
                            child: Text(
                              "SafeNet AI – Transparent Complaint Tracking",
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


  ///  READY FOR FIRESTORE (ENABLE LATER)
  
  Widget _firestoreList(String filter) {
    Query query = FirebaseFirestore.instance.collection("complaints");

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

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18), //  SPACE BETWEEN CARDS
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return _complaintCard(
              id: data["complaint_id"], // ✅ REAL ID FROM DB
              title: data["title"],
              name: data["username"],
              date: _formatDate(data["timestamp"]),
              status: data["status"],
            );

          },
        );
      },
    );
  }
  

  //  COMPLAINT CARD
  Widget _complaintCard({
    required String id,
    required String title,
    required String name,
    required String date,
    required String status,
  }) {
    Color statusColor = status == "Pending"
        ? const Color(0xFFFFE680)
        : status == "In Progress"
            ? const Color(0xFFBEE7E8)
            : const Color(0xFFBBF3C1);

    return Padding( //  ADDED SPACE AROUND CARD
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(
      padding: const EdgeInsets.all(16), //  slightly reduced height
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
            /// TITLE + STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id, // ✅ CMP-1001
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(name, style: const TextStyle(color: Colors.black54)),

            const SizedBox(height: 4),

            Text(date, style: const TextStyle(color: Colors.black45)),

            const SizedBox(height: 8),

           /* const Align(
              alignment: Alignment.centerRight,
              child: Text("View Details",
                  style: TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.w600)),
            ),*/
          ],
        ),
      ),
    );
  }



  //  CIRCLE ICON
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
String _formatDate(Timestamp timestamp) {
  final date = timestamp.toDate();
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return "${date.day} ${months[date.month - 1]} ${date.year}";
}
