import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';

class WorkerChatPage extends StatefulWidget {
  const WorkerChatPage({super.key});

  @override
  State<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends State<WorkerChatPage> {
  bool _isProfileOpen = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Chat states
  String? conversationId;
  bool isLoading = true;
  bool isWaiting = false;
  bool connectedToAuthority = false;
  bool hasPreviousChat = false;

  // For waiting state
  int reconnectSeconds = 300;
  Timer? reconnectTimer;
  StreamSubscription? statusListener;

  // Bot messages (only shown when not connected)
  List<Map<String, dynamic>> botMessages = [];

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    reconnectTimer?.cancel();
    statusListener?.cancel();
    super.dispose();
  }

  // Check for existing request
  Future<void> _checkExistingRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        isLoading = false;
      });
      _showWelcome();
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("worker_support_requests")
          .where("workerId", isEqualTo: uid)
          .get();

      final now = DateTime.now();

      // Clean up old requests and find valid one
      DocumentSnapshot? validDoc;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
        final ageMinutes = createdAt != null
            ? now.difference(createdAt).inMinutes
            : 999;

        if (ageMinutes > 30) {
          // Delete old requests
          await doc.reference.delete();
        } else if (validDoc == null) {
          validDoc = doc;
        } else {
          await doc.reference.delete();
        }
      }

      if (validDoc != null) {
        final data = validDoc.data() as Map<String, dynamic>;
        final status = data["status"];
        final createdAt = (data["createdAt"] as Timestamp?)?.toDate();

        if (status == "active") {
          // Has active chat - ask to continue or start new
          setState(() {
            conversationId = validDoc!.id;
            hasPreviousChat = true;
            isLoading = false;
            botMessages.add({
              "type": "bot",
              "text": "You have an active chat with authority.",
            });
            botMessages.add({
              "type": "bot",
              "text": "Would you like to continue or start a new chat?",
            });
            botMessages.add({"type": "previousChatChoice"});
          });
          return;
        } else if (status == "waiting") {
          // Restore waiting state
          final elapsedSeconds = createdAt != null
              ? now.difference(createdAt).inSeconds
              : 0;
          final remainingSeconds = 300 - elapsedSeconds;

          if (remainingSeconds > 0) {
            setState(() {
              conversationId = validDoc!.id;
              isWaiting = true;
              reconnectSeconds = remainingSeconds;
              isLoading = false;
              botMessages.add({
                "type": "bot",
                "text": "Still waiting for authority to connect...",
              });
            });
            _startTimer();
            _listenForStatusChange();
            return;
          } else {
            await validDoc.reference.delete();
          }
        }
      }
    } catch (e) {
      print("Error checking existing request: $e");
    }

    setState(() => isLoading = false);
    _showWelcome();
  }

  void _showWelcome() {
    setState(() {
      botMessages.add({
        "type": "bot",
        "text":
            "Hello! Welcome to SafeNet AI.\nI am SafeNet AI Support Bot.\nDo you want to chat with authority?",
      });
      botMessages.add({"type": "yesno"});
    });
  }

  // Continue previous chat
  void _continuePreviousChat() {
    setState(() {
      hasPreviousChat = false;
      connectedToAuthority = true;
      botMessages.clear();
    });
  }

  // Start new chat (delete old one first)
  Future<void> _startNewChat() async {
    if (conversationId != null) {
      try {
        // Delete messages
        final msgs = await FirebaseFirestore.instance
            .collection("worker_support_chats")
            .doc(conversationId)
            .collection("messages")
            .get();
        for (var doc in msgs.docs) {
          await doc.reference.delete();
        }
        // Delete chat doc
        await FirebaseFirestore.instance
            .collection("worker_support_chats")
            .doc(conversationId)
            .delete();
        // Delete request
        await FirebaseFirestore.instance
            .collection("worker_support_requests")
            .doc(conversationId)
            .delete();
      } catch (e) {
        print("Error deleting old chat: $e");
      }
    }

    setState(() {
      conversationId = null;
      hasPreviousChat = false;
      connectedToAuthority = false;
      botMessages.clear();
    });
    _showWelcome();
  }

  // Connect to authority
  Future<void> _connectToAuthority() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      botMessages.removeWhere((m) => m["type"] == "yesno");
      botMessages.add({
        "type": "bot",
        "text": "Connecting you to authority...",
      });
      isWaiting = true;
    });

    // Get worker name
    String workerName = "Worker";
    try {
      final workerDoc = await FirebaseFirestore.instance
          .collection("workers")
          .doc(uid)
          .get();
      if (workerDoc.exists) {
        workerName = workerDoc.data()?["username"] ?? "Worker";
      }
    } catch (e) {
      print("Error getting worker name: $e");
    }

    // Create request
    final doc = await FirebaseFirestore.instance
        .collection("worker_support_requests")
        .add({
          "workerId": uid,
          "workerName": workerName,
          "status": "waiting",
          "createdAt": FieldValue.serverTimestamp(),
        });

    setState(() {
      conversationId = doc.id;
      reconnectSeconds = 300;
    });

    _startTimer();
    _listenForStatusChange();
  }

  void _startTimer() {
    reconnectTimer?.cancel();
    reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (reconnectSeconds <= 0) {
        timer.cancel();
        // Timeout - delete request
        if (conversationId != null && !connectedToAuthority) {
          try {
            await FirebaseFirestore.instance
                .collection("worker_support_requests")
                .doc(conversationId)
                .delete();
          } catch (e) {
            print("Error deleting request: $e");
          }
          if (mounted) {
            setState(() {
              isWaiting = false;
              conversationId = null;
              botMessages.add({
                "type": "bot",
                "text": "Connection timeout. Authority did not respond.",
              });
              botMessages.add({"type": "yesno"});
            });
          }
        }
      } else {
        if (mounted) setState(() => reconnectSeconds--);
      }
    });
  }

  void _listenForStatusChange() {
    if (conversationId == null) return;

    statusListener?.cancel();
    statusListener = FirebaseFirestore.instance
        .collection("worker_support_requests")
        .doc(conversationId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;

          final status = snapshot["status"];
          if (status == "active" && !connectedToAuthority) {
            reconnectTimer?.cancel();
            setState(() {
              connectedToAuthority = true;
              isWaiting = false;
              botMessages.clear();
            });
          }
        });
  }

  // Send message
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || conversationId == null || !connectedToAuthority) return;

    _controller.clear();

    await FirebaseFirestore.instance
        .collection("worker_support_chats")
        .doc(conversationId)
        .collection("messages")
        .add({
          "sender": "worker",
          "text": text,
          "timestamp": FieldValue.serverTimestamp(),
        });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Support Chat",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          NotificationDropdown(role: "worker"),
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: () => setState(() => _isProfileOpen = true),
                            child: _circleButton(Icons.person),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Status chip
                _buildStatusChip(),

                // Timer
                if (isWaiting && !connectedToAuthority)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Time remaining: ${(reconnectSeconds ~/ 60).toString().padLeft(2, '0')}:${(reconnectSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Chat area
                Expanded(child: _buildChatArea()),

                // Input bar
                _buildInputBar(),
              ],
            ),
          ),

          // Profile sidebar
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
                userCollection: "workers",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    if (connectedToAuthority) {
      color = Colors.green;
      text = "Connected to Authority";
    } else if (hasPreviousChat) {
      color = Colors.purple;
      text = "Previous Chat Found";
    } else if (isWaiting) {
      color = Colors.blue;
      text = "Waiting for Authority...";
    } else {
      color = Colors.orange;
      text = "Chatting with Bot";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildChatArea() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // When connected, use StreamBuilder like authority chat
    if (connectedToAuthority && conversationId != null) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("worker_support_chats")
            .doc(conversationId)
            .collection("messages")
            .orderBy("timestamp", descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "Connected! Start chatting with authority.",
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isWorker = data["sender"] == "worker";
              return _bubble(data["text"] ?? "", isWorker);
            },
          );
        },
      );
    }

    // Show bot messages when not connected
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: botMessages.length,
      itemBuilder: (context, index) {
        final msg = botMessages[index];

        if (msg["type"] == "bot") {
          return _bubble(msg["text"], false);
        }
        if (msg["type"] == "yesno") {
          return _yesNoButtons();
        }
        if (msg["type"] == "previousChatChoice") {
          return _previousChatChoiceButtons();
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controller,
                enabled: connectedToAuthority,
                decoration: InputDecoration(
                  hintText: connectedToAuthority
                      ? "Type your message..."
                      : "Connect to authority first",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: connectedToAuthority ? _sendMessage : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: connectedToAuthority
                    ? const Color(0xFF6EA7A0)
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yesNoButtons() {
    return Wrap(
      spacing: 10,
      children: [
        GestureDetector(onTap: _connectToAuthority, child: _glassButton("YES")),
        _glassButton("NO"),
      ],
    );
  }

  Widget _glassButton(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _previousChatChoiceButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _continuePreviousChat,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.green.withOpacity(0.6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 18, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      "Continue",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _startNewChat,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.blue.withOpacity(0.6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_comment, size: 18, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      "Start New",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6EA7A0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
