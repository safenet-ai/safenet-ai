import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wastepickup.dart';
import 'widget/profile_sidebar.dart';
import 'widget/filter_tabs.dart';
class WastePickupPage extends StatefulWidget {
  const WastePickupPage({super.key});

  @override
  State<WastePickupPage> createState() => _WastePickupPageState();
}

class _WastePickupPageState extends State<WastePickupPage> {

  bool _isProfileOpen = false;

  String selectedFilter = "All";
  final PageController _pageController = PageController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/bg1_img.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Soft overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.35),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(0.10),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: _circleIcon(Icons.arrow_back),
                        ),
                        Row(
                          children: [
                            _circleIcon(Icons.notifications_none),
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

                    const SizedBox(height: 40),

                    // MAIN TITLE
                    const Center(
                      child: Text(
                        "Waste Pickup",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black26,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // REQUEST PICKUP BUTTON
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Navigate to New Complaint Page
                            Navigator.push(context, MaterialPageRoute(builder: (_) => NewWastePickupRequestPage()));
                          },
                          child: Container(
                            width: double.infinity,   // <<< FULL RESPONSIVE WIDTH
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,           // perfect height like filter buttons
                            ),
                          decoration: BoxDecoration(
                            color: const Color(0xffb9efe0),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Request Pickup",
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

                    // FILTER TABS
                    // FILTER TABS (match service page style - each tab expands)

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FilterTabs(
                        selected: selectedFilter,
                        tabs:  [
                          FilterTabItem("All", Icons.apps),
                          FilterTabItem("Scheduled", Icons.schedule),
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

                    SizedBox(
                      height: 420,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) {
                          setState(() {
                            selectedFilter =
                                ["All", "Scheduled", "Completed"][i];
                          });
                        },
                        children: [
                          _pickupList("All"),
                          _pickupList("Scheduled"),
                          _pickupList("Completed"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
              width: MediaQuery.of(context).size.width * 0.33,
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


  // PICKUP LIST
  Widget _pickupList(String filter) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("User not logged in"));
    }

    Query query = FirebaseFirestore.instance
        .collection("waste_pickups")
        .where("userId", isEqualTo: user.uid);

    if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy("timestamp", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No pickup requests found"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(4),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return _pickupCard(
              id: data["pickup_id"],        // ✅ FIRESTORE PICKUP ID
              date: data["date"],          // ✅ Scheduled Date
              time: data["time"],          // ✅ Scheduled Time
              type: data["wasteType"],     // ✅ Waste Type
              status: data["status"],      // ✅ Status pill
            );
          },
        );
      },
    );
  }


  // PICKUP CARD
  Widget _pickupCard({
    required String id,
    required String date,
    required String time,
    required String type,
    required String status,
  }) {
    Color statusColor = status == "Scheduled"
        ? const Color(0xFFFFE680)
        : const Color(0xFFBBF3C1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        /// ✅ TOP ROW (ID + STATUS)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Pickup ID",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        /// ✅ PICKUP ID VALUE
        Text(
          id,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        /// ✅ DATE + TIME
        Text(
          "$date • $time",
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),

        const SizedBox(height: 10),

        /// ✅ TYPE
        Text(
          "Type: $type",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}
