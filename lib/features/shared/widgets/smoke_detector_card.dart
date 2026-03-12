import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class SmokeDetectorCard extends StatefulWidget {
  final String? deviceId;
  const SmokeDetectorCard({super.key, this.deviceId});

  @override
  State<SmokeDetectorCard> createState() => _SmokeDetectorCardState();
}

class _SmokeDetectorCardState extends State<SmokeDetectorCard> {
  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _stalenessTimer;

  String _level = "SAFE";
  String _type = "NONE";
  int _deviceLastUpdatedMs = 0; // The ESP32's own lastUpdated timestamp
  bool _dataReceived = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print('🔍 SmokeDetectorCard initState: deviceId=${widget.deviceId}');
    _startListening();
    _stalenessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startListening() {
    final id = widget.deviceId;
    print('🔍 SmokeDetectorCard _startListening: id=$id');
    if (id == null || id.isEmpty) {
      print('🔍 SmokeDetectorCard: deviceId is null/empty — showing no sensor');
      if (mounted) setState(() => _loading = false);
      return;
    }

    final path = 'devices/$id';
    print('🔍 SmokeDetectorCard: Listening to RTDB path: $path');

    final dbUrl = Firebase.app().options.databaseURL;
    print('🔍 SmokeDetectorCard: databaseURL from FirebaseOptions = $dbUrl');

    late FirebaseDatabase db;
    if (dbUrl != null && dbUrl.isNotEmpty) {
      db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: dbUrl,
      );
    } else {
      db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://safenet-og-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
    }

    _sub = db
        .ref(path)
        .onValue
        .listen(
          (event) {
            if (!mounted) return;
            final value = event.snapshot.value;
            print(
              '🔍 SmokeDetectorCard: Event received! value=$value, exists=${event.snapshot.exists}',
            );

            if (value == null) {
              setState(() {
                _dataReceived = false;
                _loading = false;
              });
              return;
            }

            String level = "SAFE";
            String type = "NONE";
            int deviceTs = 0;

            try {
              final raw = value as Map;
              level = raw['level']?.toString() ?? "SAFE";
              type = raw['type']?.toString() ?? "NONE";

              // Read the ESP32's own lastUpdated timestamp.
              // ESP32 typically sends Unix time in SECONDS (e.g. 1741651200),
              // but we need milliseconds for comparison with DateTime.now().millisecondsSinceEpoch.
              // Values < 1e12 are in seconds; values >= 1e12 are already in milliseconds.
              final dynamic rawTs = raw['lastUpdated'];
              if (rawTs is int) {
                deviceTs = rawTs < 1000000000000 ? rawTs * 1000 : rawTs;
              } else if (rawTs is double) {
                final tsInt = rawTs.toInt();
                deviceTs = tsInt < 1000000000000 ? tsInt * 1000 : tsInt;
              } else if (rawTs is String) {
                final parsed = int.tryParse(rawTs) ?? 0;
                deviceTs = parsed < 1000000000000 ? parsed * 1000 : parsed;
              }

              final now = DateTime.now().millisecondsSinceEpoch;
              final ageSeconds = deviceTs > 0 ? (now - deviceTs) ~/ 1000 : -1;
              print(
                '🔍 SmokeDetectorCard: Parsed — level=$level, type=$type, lastUpdated=$deviceTs (ms), age=${ageSeconds}s',
              );
            } catch (e) {
              print('🔍 SmokeDetectorCard: Parse error: $e');
            }

            setState(() {
              _level = level;
              _type = type;
              _deviceLastUpdatedMs = deviceTs;
              _dataReceived = true;
              _loading = false;
            });
          },
          onError: (e) {
            print('🔍 SmokeDetectorCard: onError: $e');
            if (mounted) {
              setState(() {
                _dataReceived = false;
                _loading = false;
              });
            }
          },
        );
  }

  /// Offline if the ESP32's lastUpdated is > 30 seconds old.
  /// 30 s gives enough headroom for network and processing latency.
  bool get _isOffline {
    if (!_dataReceived) return true;
    if (_deviceLastUpdatedMs == 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - _deviceLastUpdatedMs;
    return age > 30000; // 30 seconds in ms
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stalenessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.deviceId;
    if (id == null || id.isEmpty) {
      return _buildCard(
        level: "DISCONNECTED",
        type: "NONE",
        messageOverride: "No Sensor Assigned",
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_dataReceived) {
      // No data from RTDB (path doesn't exist or permission denied) → show offline
      return _buildCard(level: "OFFLINE", type: "NONE");
    }

    if (_isOffline) {
      return _buildCard(level: "OFFLINE", type: _type);
    }

    return _buildCard(level: _level, type: _type);
  }

  Widget _buildCard({
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
