import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmokeDetectorCard extends StatelessWidget {
  final String? deviceId;
  const SmokeDetectorCard({super.key, this.deviceId});

  @override
  Widget build(BuildContext context) {
    if (deviceId == null || deviceId!.isEmpty) {
      return _buildCard(
        context,
        level: "DISCONNECTED",
        type: "NONE",
        messageOverride: "No Sensor Assigned",
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Document doesn't exist yet, we can show a disconnected state
          return _buildCard(
            context,
            level: "DISCONNECTED",
            type: "NONE",
            messageOverride: "Sensor Not Found",
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String level = data['level']?.toString() ?? "SAFE";
        final String type = data['type']?.toString() ?? "NONE";
        final int lastUpdated = data['lastUpdated'] ?? 0;

        // Check if data is stale (e.g., > 1 minute old)
        final now = DateTime.now().millisecondsSinceEpoch;
        final bool isStale = (now - lastUpdated) > 60000;

        if (isStale) {
          return _buildCard(context, level: "OFFLINE", type: type);
        }

        return _buildCard(context, level: level, type: type);
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String level,
    required String type,
    String? messageOverride,
  }) {
    Color bgColor;
    Color iconColor;
    IconData iconData;
    String message;

    if (level == "HIGH") {
      bgColor = Colors.red.shade100;
      iconColor = Colors.red;
      iconData = Icons.warning_amber_rounded;
      message = "DANGER: $type DETECTED!";
    } else if (level == "LOW") {
      bgColor = Colors.orange.shade100;
      iconColor = Colors.deepOrange;
      iconData = Icons.error_outline;
      message = "WARNING: Elevating levels";
    } else if (level == "OFFLINE" || level == "DISCONNECTED") {
      bgColor = Colors.grey.shade200;
      iconColor = Colors.grey.shade600;
      iconData = Icons.cloud_off;
      message = "Sensor Offline";
    } else {
      bgColor = const Color(0xFFD7F5E8); // Matches Waste Pickup green
      iconColor = Colors.green.shade700;
      iconData = Icons.check_circle_outline;
      message = "Air Quality Safe";
    }

    if (messageOverride != null) {
      message = messageOverride;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 32, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Smoke & Gas Monitor",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
