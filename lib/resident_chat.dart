import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/profile_sidebar.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {

  bool _isProfileOpen = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool connectedToAuthority = false;
  String? conversationId;

  int reconnectSeconds = 300;
  Timer? reconnectTimer;
  StreamSubscription? authorityListener;
  StreamSubscription? messageListener; // ✅ FIX: message listener added

  List<Map<String, dynamic>> messages = [];

  final List<Map<String, String>> complaints = [
    {"title": "Water Leakage", "desc": "Pipe leaking in kitchen"},
    {"title": "Power Cut", "desc": "No electricity since morning"},
  ];

  final List<Map<String, String>> services = [
    {"title": "AC Repair", "desc": "AC not cooling"},
    {"title": "Plumbing", "desc": "Bathroom tap broken"},
  ];

  final List<Map<String, String>> wastePickups = [
    {"title": "Missed Pickup", "desc": "Garbage not collected"},
  ];

  // ---------------- SEND MESSAGE ----------------
  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    setState(() {
      messages.add({"type": "user", "text": text});
    });

    if (conversationId != null && connectedToAuthority) {
      await FirebaseFirestore.instance
          .collection("support_chats")
          .doc(conversationId)
          .collection("messages")
          .add({
        "sender": "resident",
        "text": text,
        "timestamp": FieldValue.serverTimestamp(),
      });
    }

    if (messages.length == 1) _botWelcome();
    _scrollToBottom();
  }

  // ---------------- BOT WELCOME ----------------
  void _botWelcome() {
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        messages.add({
          "type": "bot",
          "text":
              "Hello! Welcome to SafeNet AI.\nI am SafeNet AI Support Bot.\nWhat help do you need today?"
        });
        messages.add({"type": "category"});
      });
      _scrollToBottom();
    });
  }

  void _selectCategory(String category) {
    setState(() {
      messages.removeLast();
      messages.add({"type": "user", "text": category});
    });

    if (category == "Other") {
      _askAuthority();
      return;
    }

    List<Map<String, String>> data = [];
    if (category == "Complaints") data = complaints;
    if (category == "Service") data = services;
    if (category == "Waste Pickup") data = wastePickups;

    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() {
        for (var item in data) {
          messages.add({
            "type": "selectable",
            "title": item['title'],
            "desc": item['desc']
          });
        }

        messages.add({
          "type": "bot",
          "text": "Which one do you need help with?"
        });
      });

      _scrollToBottom();
    });
  }

  void _selectItem(Map<String, String> item) {
    setState(() {
      messages.add({
        "type": "bot",
        "text": "Selected:\n${item['title']}\n${item['desc']}"
      });
    });
    _askAuthority();
  }

  void _askAuthority() {
    setState(() {
      messages.add({
        "type": "bot",
        "text": "Do you want to chat with authority?"
      });
      messages.add({"type": "yesno"});
    });

    _scrollToBottom();
  }

  // ✅ ✅ ✅ ONLY FIXED SECTION ✅ ✅ ✅
  Future<void> _connectToAuthority() async {
    setState(() {
      messages.removeLast();
      messages.add({
        "type": "bot",
        "text": "Connecting you to authority..."
      });
    });

    _startReconnectTimer();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";

    final doc = await FirebaseFirestore.instance
        .collection("support_requests")
        .add({
      "residentId": uid,
      "residentName": "Resident",
      "status": "waiting",
      "createdAt": FieldValue.serverTimestamp(),
    });

    conversationId = doc.id;

    authorityListener = FirebaseFirestore.instance
        .collection("support_requests")
        .doc(conversationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot["status"] == "active") {
        reconnectTimer?.cancel();

        setState(() {
          connectedToAuthority = true;
          messages.add({
            "type": "authority",
            "text": "Hello! I am the authority. How can I assist you?"
          });
        });

        _scrollToBottom();

        // ✅ ✅ ✅ THIS FIXES YOUR ISSUE ✅ ✅ ✅
        messageListener = FirebaseFirestore.instance
            .collection("support_chats")
            .doc(conversationId)
            .collection("messages")
            .orderBy("timestamp", descending: false)
            .snapshots()
            .listen((snapshot) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data["sender"] == "authority") {
              if (!messages.any((m) => m["text"] == data["text"])) {
                setState(() {
                  messages.add({
                    "type": "authority",
                    "text": data["text"],
                  });
                });
                _scrollToBottom();
              }
            }
          }
        });
      }
    });
  }

  // ---------------- RECONNECT TIMER ----------------
  void _startReconnectTimer() {
    reconnectSeconds = 300;

    reconnectTimer?.cancel();
    reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (reconnectSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => reconnectSeconds--);
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    authorityListener?.cancel();
    messageListener?.cancel();
    reconnectTimer?.cancel();
    super.dispose();
  }

  // ---------------- UI (UNCHANGED) ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/bg1_img.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.white.withOpacity(0.18)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),

                      const Text(
                        "Support chat",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Row(
                        children: [
                          _circleButton(Icons.notifications_none_rounded),
                          const SizedBox(width: 12),
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

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: connectedToAuthority
                        ? Colors.green.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    connectedToAuthority
                        ? "Connected to Authority"
                        : "Chatting with Support Bot",
                    style: TextStyle(
                        color: connectedToAuthority
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),

                if (!connectedToAuthority && reconnectSeconds < 300)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Reconnect in ${(reconnectSeconds ~/ 60).toString().padLeft(2, '0')}:${(reconnectSeconds % 60).toString().padLeft(2, '0')}",
                    ),
                  ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];

                      if (msg["type"] == "user") return _bubble(msg["text"], true);
                      if (msg["type"] == "bot") return _bubble(msg["text"], false);
                      if (msg["type"] == "authority")
                        return _bubble(msg["text"], false);

                      if (msg["type"] == "selectable") {
                        return GestureDetector(
                          onTap: () => _selectItem({
                            "title": msg["title"],
                            "desc": msg["desc"],
                          }),
                          child: _glassSelectable(
                              "${msg["title"]}\n${msg["desc"]}"),
                        );
                      }

                      if (msg["type"] == "category") {
                        return _inlineOptions(
                            ["Complaints", "Service", "Waste Pickup", "Other"]);
                      }

                      if (msg["type"] == "yesno") {
                        return _inlineOptions(["YES", "NO"], isYesNo: true);
                      }

                      return const SizedBox();
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                                hintText: "Type your message...",
                                border: InputBorder.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6EA7A0),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(Icons.send, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                ),
              ],
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

  Widget _inlineOptions(List<String> options, {bool isYesNo = false}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((text) {
        return _glassOption(text, isYesNo: isYesNo);
      }).toList(),
    );
  }

  Widget _glassOption(String text, {bool isYesNo = false}) {
    return GestureDetector(
      onTap: () {
        if (isYesNo && text == "YES") {
          _connectToAuthority();
        } else {
          _selectCategory(text);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Text(text,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _glassSelectable(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _bubble(String text, bool isUser) {
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isUser ? const Color(0xFF6EA7A0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text,
            style: TextStyle(
                color:
                    isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
