import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IndexStatusBanner extends StatefulWidget {
  final String testCollection;
  final Map<String, dynamic> testQuery;

  const IndexStatusBanner({
    super.key,
    this.testCollection = "incidents",
    this.testQuery = const {},
  });

  @override
  State<IndexStatusBanner> createState() => _IndexStatusBannerState();
}

class _IndexStatusBannerState extends State<IndexStatusBanner> {
  bool _isChecking = true;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _checkIndexStatus();
  }

  Future<void> _checkIndexStatus() async {
    setState(() {
      _isChecking = true;
      _hasError = false;
    });

    try {
      await FirebaseFirestore.instance
          .collection(widget.testCollection)
          .limit(1)
          .get();

      setState(() {
        _isChecking = false;
        _hasError = false;
      });
    } catch (e) {
      final error = e.toString();
      if (error.contains('index') || error.contains('FAILED_PRECONDITION')) {
        setState(() {
          _isChecking = false;
          _hasError = true;
          _errorMessage = "Database setup in progress";
        });
      } else {
        setState(() {
          _isChecking = false;
          _hasError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasError) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Please wait 5-10 minutes...",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _checkIndexStatus,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
