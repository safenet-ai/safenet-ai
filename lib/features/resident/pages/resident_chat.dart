import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../../services/notification_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
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
  StreamSubscription? messageListener;

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
    messageListener?.cancel();
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
          .collection("support_requests")
          .where("residentId", isEqualTo: uid)
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
            "Hello! Welcome to SafeNet AI.\nI am SafeNet AI Support Bot.\nWhat help do you need today?",
      });
      botMessages.add({"type": "category"});
    });
  }

  void _selectCategory(String category) {
    setState(() {
      botMessages.removeWhere((m) => m["type"] == "category");
      botMessages.add({"type": "user", "text": category});
    });

    if (category == "Other") {
      _askAuthority();
      return;
    }

    // Show loading message
    setState(() {
      botMessages.add({
        "type": "bot",
        "text": "Loading your ${category.toLowerCase()}...",
      });
    });

    // Fetch real data from Firestore
    _fetchUserData(category);
  }

  Future<void> _fetchUserData(String category) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      String collectionName = "";
      if (category == "Complaints") collectionName = "complaints";
      if (category == "Service") collectionName = "service_requests";
      if (category == "Waste Pickup") collectionName = "waste_pickups";

      final querySnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where("userId", isEqualTo: uid)
          .limit(10)
          .get();

      // Remove loading message
      setState(() {
        botMessages.removeWhere(
          (m) => m["text"]?.toString().contains("Loading") ?? false,
        );
      });

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          botMessages.add({
            "type": "bot",
            "text":
                "You don't have any ${category.toLowerCase()} yet.\nWould you like to discuss this with authority?",
          });
          botMessages.add({"type": "yesno"});
        });
        _scrollToBottom();
        return;
      }

      setState(() {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          String title = "";
          String desc = "";
          String status = data["status"] ?? "";

          if (category == "Complaints") {
            title = data["title"] ?? "Complaint";
            desc = "${data["description"] ?? ''}\nStatus: $status";
          } else if (category == "Service") {
            title = data["title"] ?? data["category"] ?? "Service Request";
            desc = "${data["description"] ?? ''}\nStatus: $status";
          } else if (category == "Waste Pickup") {
            title = data["wasteType"] ?? "Waste Pickup";
            desc = "Status: $status";
            if (data["date"] != null) {
              desc += "\nDate: ${data["date"]}";
            }
            if (data["time"] != null) {
              desc += "\nTime: ${data["time"]}";
            }
          }

          botMessages.add({
            "type": "selectable",
            "title": title,
            "desc": desc,
            "docId": doc.id,
          });
        }

        botMessages.add({
          "type": "bot",
          "text": "Which one do you need help with?",
        });
      });

      _scrollToBottom();
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        botMessages.removeWhere(
          (m) => m["text"]?.toString().contains("Loading") ?? false,
        );
        botMessages.add({
          "type": "bot",
          "text":
              "Sorry, couldn't load your data.\nWould you like to discuss this with authority?",
        });
        botMessages.add({"type": "yesno"});
      });
      _scrollToBottom();
    }
  }

  void _selectItem(Map<String, String> item) {
    setState(() {
      botMessages.removeWhere((m) => m["type"] == "selectable");
      botMessages.add({
        "type": "bot",
        "text": "Selected:\n${item['title']}\n${item['desc']}",
      });
    });
    _askAuthority();
  }

  void _askAuthority() {
    setState(() {
      botMessages.add({
        "type": "bot",
        "text": "Do you want to chat with authority?",
      });
      botMessages.add({"type": "yesno"});
    });

    _scrollToBottom();
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
            .collection("support_chats")
            .doc(conversationId)
            .collection("messages")
            .get();
        for (var doc in msgs.docs) {
          await doc.reference.delete();
        }
        // Delete chat doc
        await FirebaseFirestore.instance
            .collection("support_chats")
            .doc(conversationId)
            .delete();
        // Delete request
        await FirebaseFirestore.instance
            .collection("support_requests")
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

    // Get resident name
    String residentName = "Resident";
    try {
      final residentDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      if (residentDoc.exists) {
        residentName = residentDoc.data()?["username"] ?? "Resident";
      }
    } catch (e) {
      print("Error getting resident name: $e");
    }

    // Create request
    final doc = await FirebaseFirestore.instance
        .collection("support_requests")
        .add({
          "residentId": uid,
          "residentName": residentName,
          "status": "waiting",
          "createdAt": FieldValue.serverTimestamp(),
        });

    setState(() {
      conversationId = doc.id;
      reconnectSeconds = 300;
    });

    // Save chatbot conversation history to Firestore
    // This allows authority to see what the resident discussed with the bot
    try {
      final chatRef = FirebaseFirestore.instance
          .collection("support_chats")
          .doc(doc.id)
          .collection("messages");

      int order = 0;
      for (var msg in botMessages) {
        if (msg["type"] == "bot" || msg["type"] == "user") {
          await chatRef.add({
            "sender": msg["type"] == "user" ? "resident" : "bot",
            "text": msg["text"],
            "timestamp": FieldValue.serverTimestamp(),
            "order": order++, // To maintain correct order
          });
        }
      }
    } catch (e) {
      print("Error saving chat history: $e");
    }

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
                .collection("support_requests")
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
        .collection("support_requests")
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
        .collection("support_chats")
        .doc(conversationId)
        .collection("messages")
        .add({
          "sender": "resident",
          "text": text,
          "timestamp": FieldValue.serverTimestamp(),
        });

    // Notify Authority
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String residentName = "Resident";
      if (uid != null) {
        final residentDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
        if (residentDoc.exists) {
          residentName = residentDoc.data()?["username"] ?? "Resident";
        }
      }

      await NotificationService.sendNotification(
        toRole: "authority",
        userRole: "authority",
        title: "New Message from $residentName",
        body: text,
        type: "chat_message",
        additionalData: {"conversationId": conversationId},
      );
    } catch (e) {
      print("Error sending chat notification to authority: $e");
    }

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

  // ---------------- UI (UNCHANGED) ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                          NotificationDropdown(role: "user"),
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleButton(Icons.person),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Status badge
                _buildStatusBadge(),

                const SizedBox(height: 10),

                // Chat area
                Expanded(child: _buildChatArea()),

                // Input bar
                _buildInputBar(),
              ],
            ),
          ),

          // Profile sidebar
          if (_isProfileOpen) ...{
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
          },
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String text;
    Color color;

    if (isWaiting) {
      color = Colors.orange;
      text =
          "Waiting... ${(reconnectSeconds ~/ 60).toString().padLeft(2, '0')}:${(reconnectSeconds % 60).toString().padLeft(2, '0')}";
    } else if (connectedToAuthority) {
      color = Colors.green;
      text = "Connected to Authority";
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

    // When connected, use StreamBuilder
    if (connectedToAuthority && conversationId != null) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("support_chats")
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
              final isResident = data["sender"] == "resident";
              return _bubble(data["text"] ?? "", isResident);
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
        if (msg["type"] == "user") {
          return _bubble(msg["text"], true);
        }
        if (msg["type"] == "yesno") {
          return _yesNoButtons();
        }
        if (msg["type"] == "previousChatChoice") {
          return _previousChatChoiceButtons();
        }
        if (msg["type"] == "category") {
          return _categoryButtons();
        }
        if (msg["type"] == "selectable") {
          return GestureDetector(
            onTap: () =>
                _selectItem({"title": msg["title"], "desc": msg["desc"]}),
            child: _selectableCard("${msg["title"]}\n${msg["desc"]}"),
          );
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
                decoration: const InputDecoration(
                  hintText: "Type your message...",
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
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

  // Helper widgets
  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _bubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6EA7A0) : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _yesNoButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _connectToAuthority,
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
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      "YES",
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
              onTap: () {
                setState(() {
                  botMessages.removeWhere((m) => m["type"] == "yesno");
                  botMessages.add({
                    "type": "bot",
                    "text": "Okay, let me know if you need anything else!",
                  });
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.red.withOpacity(0.6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, size: 18, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      "NO",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
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
                    Icon(Icons.add_circle, size: 18, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      "New Chat",
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

  Widget _categoryButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _categoryButton(
            "Complaints",
            Icons.description_outlined,
            Colors.blue,
          ),
          _categoryButton("Service", Icons.build_outlined, Colors.purple),
          _categoryButton("Waste Pickup", Icons.delete_outline, Colors.green),
          _categoryButton("Other", Icons.more_horiz, Colors.orange),
        ],
      ),
    );
  }

  Widget _categoryButton(String text, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _selectCategory(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectableCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade700),
        ],
      ),
    );
  }
}
