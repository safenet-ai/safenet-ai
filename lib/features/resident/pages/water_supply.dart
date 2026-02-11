import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/notification_dropdown.dart';

class WaterSupplyPage extends StatefulWidget {
  const WaterSupplyPage({super.key});

  @override
  State<WaterSupplyPage> createState() => _WaterSupplyPageState();
}

class _WaterSupplyPageState extends State<WaterSupplyPage> {
  bool _isProfileOpen = false;
  String selectedFilter = "All";
  final PageController _pageController = PageController();

  final List<String> waterTypes = [
    "20L Jar (Bubble Top)",
    "1000L Tanker (Small)",
    "5000L Tanker (Large)",
    "10000L Tanker (Extra Large)",
  ];

  String? _selectedType;
  int _quantity = 1;
  DateTime _selectedDate = DateTime.now();
  
  // NEW: selected worker
  Map<String, dynamic>? selectedWorker;

  // Stream for Water Suppliers
  Stream<QuerySnapshot> _workersStream() {
    return FirebaseFirestore.instance
        .collection("workers")
        .where("isActive", isEqualTo: true)
        .where("profession", isEqualTo: "Water Supplier") // Filter for Water Suppliers
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png',
              fit: BoxFit.cover,
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

                    // HEADER
                    Row(
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
                              onTap: () => setState(() => _isProfileOpen = true),
                              child: _circleIcon(Icons.person),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Center(
                      child: Text(
                        "Water Supply",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black26,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ORDER BUTTON
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => _showOrderBottomSheet(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
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
                              "Order Water",
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

                    const SizedBox(height: 40),

                    // TABS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FilterTabs(
                        selected: selectedFilter,
                        tabs: [
                          FilterTabItem("All", Icons.apps),
                          FilterTabItem("Pending", Icons.schedule),
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

                    const SizedBox(height: 25),

                    // LIST VIEW
                    SizedBox(
                      height: 500,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) {
                          setState(() {
                            selectedFilter = ["All", "Pending", "Delivered"][i];
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

  void _showOrderBottomSheet(BuildContext context) {
    _selectedType = null;
    _quantity = 1;
    _selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Order Water Supply",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // TYPE DROPDOWN
                const Text("Select Type", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      hint: const Text("Select Standard Options"),
                      items: waterTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) => setStateSheet(() => _selectedType = val),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // WORKER SELECTION
                const Text("Select Supplier", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openWorkerPicker(setStateSheet),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedWorker != null 
                            ? selectedWorker!['name'] 
                            : "Choose Water Supplier",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedWorker != null ? Colors.black87 : Colors.black54
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // QUANTITY
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Quantity", style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_quantity > 1) setStateSheet(() => _quantity--);
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          "$_quantity",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () {
                            setStateSheet(() => _quantity++);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // DATE PICKER
                const Text("Select Date", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setStateSheet(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitOrder(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text(
                      "Submit Order",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

  }

  // WORKER PICKER
  Future<void> _openWorkerPicker(StateSetter setStateSheet) async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "Select Water Supplier",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 15),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _workersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text("No water suppliers available"));
                    }

                    // SORT: On Duty first
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aAvail = aData['isAvailable'] ?? false;
                      final bAvail = bData['isAvailable'] ?? false;
                      if (aAvail == bAvail) return 0;
                      return aAvail ? -1 : 1;
                    });

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        
                        return _workerListTile(
                          {
                            "id": docs[index].id,
                            "name": data["username"] ?? "Worker",
                            "role": data["profession"] ?? "Unknown",
                            "rating": (data["rating"] ?? 0).toDouble(),
                            "completed": data["completedWorks"] ?? 0,
                            "avatarColor": Colors.blueGrey,
                            "isAvailable": data['isAvailable'] ?? false,
                          },
                          () {
                            Navigator.pop(context, {
                              "id": docs[index].id,
                              "name": data["username"],
                              "role": data["profession"],
                              "rating": (data["rating"] ?? 0).toDouble(),
                              "completed": data["completedWorks"] ?? 0,
                              "avatarColor": Colors.blueGrey,
                              "isAvailable": data['isAvailable'] ?? false,
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (chosen != null) {
      setStateSheet(() => selectedWorker = chosen);
    }
  }

  Widget _workerListTile(Map<String, dynamic> w, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (w['avatarColor'] as Color).withOpacity(0.95),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (w['name'] as String).split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(w['role'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (w['isAvailable'] ?? false) ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (w['isAvailable'] ?? false) ? "On Duty" : "Off Duty",
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder(BuildContext context) async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a water type")),
      );
      return;
    }

    if (selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a supplier")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Generate Order ID similar to other services
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('water_orders');
      String orderId = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int lastNumber = snapshot.exists ? (snapshot['lastNumber'] ?? 1000) : 1000;
        int newNumber = lastNumber + 1;
        transaction.set(counterRef, {'lastNumber': newNumber});
        return "WATER-$newNumber";
      });

      await FirebaseFirestore.instance.collection('water_orders').add({
        "orderId": orderId,
        "userId": user.uid,
        "type": _selectedType,
        "quantity": _quantity,
        "scheduledDate": Timestamp.fromDate(_selectedDate),
        "status": "Pending",
        "timestamp": Timestamp.now(),
        // Worker Info
        "assignedWorker": {
          "id": selectedWorker!['id'],
          "name": selectedWorker!['name'],
          "role": selectedWorker!['role'],
        }
      });

      Navigator.pop(context);
      _showSuccessDialog(orderId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Order Placed!"),
        content: Text("Your water order $orderId has been placed successfully."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _orderList(String filter) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please login"));

    Query query = FirebaseFirestore.instance
        .collection('water_orders')
        .where('userId', isEqualTo: user.uid);

    if (filter != "All") {
      query = query.where('status', isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No orders found"));
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 15),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = (data['scheduledDate'] as Timestamp).toDate();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['orderId'] ?? 'ID',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: data['status'] == "Pending" ? Colors.orange[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          data['status'] ?? 'Unknown',
                          style: TextStyle(
                            color: data['status'] == "Pending" ? Colors.orange[800] : Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${data['type']} x ${data['quantity']}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEE, MMM d').format(date),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
