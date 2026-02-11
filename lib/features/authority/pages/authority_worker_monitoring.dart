import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class AuthorityWorkerMonitoringPage extends StatefulWidget {
  const AuthorityWorkerMonitoringPage({super.key});

  @override
  State<AuthorityWorkerMonitoringPage> createState() =>
      _AuthorityWorkerMonitoringPageState();
}

class _AuthorityWorkerMonitoringPageState
    extends State<AuthorityWorkerMonitoringPage> {
  String selectedFilter = "All"; // "All", "On Duty", "Off Duty"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // Ensure this asset exists
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ------------------ APP BAR ------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Worker Monitoring",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------ STREAM CONTENT ------------------
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('workers').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No workers found."));
                      }

                      final allWorkers = snapshot.data!.docs;
                      
                      // Calculate Stats
                      int total = allWorkers.length;
                      int onDuty = 0;
                      int offDuty = 0;

                      for (var doc in allWorkers) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isAvailable = data['isAvailable'] ?? false;
                        if (isAvailable) {
                          onDuty++;
                        } else {
                          offDuty++;
                        }
                      }

                      // Filter List
                      List<QueryDocumentSnapshot> filteredList = allWorkers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isAvailable = data['isAvailable'] ?? false;
                        if (selectedFilter == "On Duty") return isAvailable;
                        if (selectedFilter == "Off Duty") return !isAvailable;
                        return true;
                      }).toList();

                      // Sort: On Duty first
                      filteredList.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aAvail = aData['isAvailable'] ?? false;
                        final bAvail = bData['isAvailable'] ?? false;
                        if (aAvail == bAvail) return 0;
                        return aAvail ? -1 : 1;
                      });

                      return Column(
                        children: [
                          // ------------------ STATS CARDS ------------------
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                _statCard("Total", total.toString(), Colors.blue.shade100, Colors.blue.shade800),
                                const SizedBox(width: 12),
                                _statCard("On Duty", onDuty.toString(), Colors.green.shade100, Colors.green.shade800),
                                const SizedBox(width: 12),
                                _statCard("Off Duty", offDuty.toString(), Colors.grey.shade300, Colors.grey.shade800),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ------------------ FILTERS ------------------
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: ["All", "On Duty", "Off Duty"].map((filter) {
                                final isSelected = selectedFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ChoiceChip(
                                    label: Text(
                                      filter,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: Colors.deepPurpleAccent,
                                    backgroundColor: Colors.white.withOpacity(0.8),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => selectedFilter = filter);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ------------------ LIST ------------------
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final data = filteredList[index].data() as Map<String, dynamic>;
                                return _workerCard(data);
                              },
                            ),
                          ),
                        ],
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

  Widget _statCard(String label, String value, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workerCard(Map<String, dynamic> data) {
    final isAvailable = data['isAvailable'] ?? false;
    final name = data['username'] ?? "Unknown Worker";
    final profession = data['profession'] ?? "General";
    final phone = data['phone'] ?? "N/A";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green.shade100 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: isAvailable ? Colors.green.shade700 : Colors.grey.shade600,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  profession,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAvailable ? "On Duty" : "Off Duty",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
