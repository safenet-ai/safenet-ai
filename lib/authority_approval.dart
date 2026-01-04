import 'package:flutter/material.dart';
import 'widget/filter_tabs.dart';
import 'widget/profile_sidebar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  String searchText = "";
  String selectedTab = "Residents";
  String status = "Pending";
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isProfileOpen = false;

  Stream<QuerySnapshot> _usersByStatus(String tab, String status) {
    final collection = tab == "Residents" ? "users" : "workers";

    return FirebaseFirestore.instance
        .collection(collection)
        .where("approvalStatus", isEqualTo: status)
        .snapshots();
  }

  Stream<int> pendingCountStream(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where("approvalStatus", isEqualTo: "pending")
        .snapshots()
        .map((snap) => snap.docs.length);
  }
  



  Future<void> _approveUser(String uid) async {
    final collection = selectedTab == "Residents" ? "users" : "workers";

    final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
    final data = doc.data()!;

    await FirebaseFirestore.instance.collection(collection).doc(uid).update({
      "approvalStatus": "approved",
      "isActive": true,
    });

    await _logApprovalAction(
      uid: uid,
      name: data["username"],
      email: data["email"],
      role: selectedTab.toLowerCase(),
      action: "approved",
    );

    await _sendNotification(
      uid: uid,
      title: "Account Approved",
      message: "Your SafeNet ${selectedTab.toLowerCase()} account has been approved. You can now use the app.",
    );
  }



  Future<void> _rejectUser(String uid) async {
    final collection = selectedTab == "Residents" ? "users" : "workers";

    final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
    final data = doc.data()!;

    await FirebaseFirestore.instance.collection(collection).doc(uid).update({
      "approvalStatus": "rejected",
      "isActive": false,
    });

    await _logApprovalAction(
      uid: uid,
      name: data["username"],
      email: data["email"],
      role: selectedTab.toLowerCase(),
      action: "rejected",
    );

    await _sendNotification(
      uid: uid,
      title: "Account Rejected",
      message: "Your SafeNet ${selectedTab.toLowerCase()} account was rejected by the authority.",
    );
  }



  Future<void> _logApprovalAction({
    required String uid,
    required String name,
    required String email,
    required String role,
    required String action,
  }) 
  async {
    final admin = FirebaseFirestore.instance.collection("approval_logs").doc();

    await admin.set({
      "uid": uid,
      "name": name,
      "email": email,
      "role": role,
      "action": action,
      "performedBy": "authority", // you can replace later with actual admin UID
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendNotification({
    required String uid,
    required String title,
    required String message,
  }) async {
    await FirebaseFirestore.instance.collection("notifications").add({
      "target": "user",
      "toUid": uid,
      "title": title,
      "message": message,
      "isRead": false,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // Background
          Positioned.fill(
            child: Image.asset(
              "assets/bg1_img.png",
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [

                    // ---------------- TOP BAR ----------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: _circleIcon(Icons.arrow_back),
                          ),

                          const SizedBox(width: 40),

                          Image.asset("assets/logo.png", height: 50),

                          const SizedBox(width: 8),

                          const Text(
                            "SafeNet AI",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey,
                            ),
                          ),

                          const Spacer(),

                          _circleIcon(Icons.notifications_none),

                          const SizedBox(width: 10),
                          
                          GestureDetector(
                              onTap: () {
                                setState(() => _isProfileOpen = true);
                              },
                              child: _circleIcon(Icons.person),
                            ),
                          
                        ],
                      ),
                    ),

                    const SizedBox(height: 50),

                    Text(
                      _currentPage == 0
                          ? "Pending Approval\nRequests"
                          : _currentPage == 1
                              ? "Approved Users"
                              : "Rejected Users",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),


                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            if (_currentPage > 0) {
                              _pageController.previousPage(
                                  duration: Duration(milliseconds: 300), curve: Curves.ease);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios),
                          onPressed: () {
                            if (_currentPage < 2) {
                              _pageController.nextPage(
                                  duration: Duration(milliseconds: 300), curve: Curves.ease);
                            }
                          },
                        ),
                      ],
                    ),


                    const SizedBox(height: 20),

                    // ---------------- SEGMENTED TABS ----------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      
                        child:FilterTabs(
                          selected: selectedTab,
                          tabs: [
                            FilterTabItem("Residents", Icons.people),
                            FilterTabItem("Workers", Icons.engineering),
                          ],
                          onChanged: (i, label) {
                            setState(() => selectedTab = label);
                          },
                        ),
                    ),

                    const SizedBox(height: 25),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.08),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (v) {
                            setState(() => searchText = v.toLowerCase());
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search by name, email, phone…",
                            icon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---------------- LIST ----------------
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) {
                          setState(() => _currentPage = i);
                        },
                        children: [
                          _buildPendingList(),
                          _buildApprovedList(),
                          _buildRejectedList(),
                        ],
                      ),
                    ),
                  ],
                ),
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

  // ---------------- APPROVAL CARD ----------------
  Widget _approvalCard({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String status,
    String? profession,
  }) 
  {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(4, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Text(email, style: const TextStyle(color: Colors.black54)),
          Text(phone, style: const TextStyle(color: Colors.black54)),
          if (profession != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Profession: $profession",
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 18),

          Row(
            children: [
              if (status == "pending") ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => _approveUser(uid),
                    child: _actionBtn("Approve", const Color(0xFFCFF6F2)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _rejectUser(uid),
                    child: _actionBtn("Reject", Colors.grey.shade200),
                  ),
                ),
              ],

              if (status == "approved")
                Expanded(
                  child: GestureDetector(
                    onTap: () => _rejectUser(uid),
                    child: _actionBtn("Disable", Colors.orange.shade100),
                  ),
                ),

              if (status == "rejected")
                Expanded(
                  child: GestureDetector(
                    onTap: () => _approveUser(uid),
                    child: _actionBtn("Re-Approve", Colors.green.shade100),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- BUTTON ----------------
  Widget _actionBtn(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(3, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ---------------- ICON ----------------
  Widget _circleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white70,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black87, size: 22),
    );
  }

  Widget _buildPendingList() {
    return _buildUserList("pending");
  }

  Widget _buildApprovedList() {
    return _buildUserList("approved");
  }

  Widget _buildRejectedList() {
    return _buildUserList("rejected");
  }

  Widget _buildUserList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersByStatus(selectedTab, status),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final profession = selectedTab == "Workers"
              ? (data["profession"] ?? "")
              : "";

          final text = (
            data["username"] +
            data["email"] +
            data["phone"] +
            profession
          ).toLowerCase();

          return text.contains(searchText);
        }).toList();



        if (docs.isEmpty) {
          return Center(child: Text("No $status users"));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return _approvalCard(
              uid: data["uid"],
              name: data["username"],
              email: data["email"],
              phone: data["phone"],             
              status: status,
              profession: selectedTab == "Workers" ? data["profession"] : null,
            );
          },
        );
      },
    );
  }


}
