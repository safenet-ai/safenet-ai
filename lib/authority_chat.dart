import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthorityChatPage extends StatefulWidget {
  final String conversationId;
  final String residentName;

  const AuthorityChatPage({
    super.key,
    required this.conversationId,
    required this.residentName,
  });

  @override
  State<AuthorityChatPage> createState() => _AuthorityChatPageState();
}

class _AuthorityChatPageState extends State<AuthorityChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ✅ SEND MESSAGE
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection("support_chats")
        .doc(widget.conversationId)
        .collection("messages")
        .add({
      "sender": "authority",
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
          // ✅ BACKGROUND IMAGE
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

                // ✅ TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),

                      Column(
                        children: [
                          const Text(
                            "Authority Support",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            "Chat with ${widget.residentName}",
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),

                      _circleButton(Icons.verified_user),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ STATUS CHIP
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Connected to Resident",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ CHAT STREAM
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("support_chats")
                        .doc(widget.conversationId)
                        .collection("messages")
                        .orderBy("timestamp", descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          final isAuthority =
                              data["sender"] == "authority";

                          return _bubble(data["text"], isAuthority);
                        },
                      );
                    },
                  ),
                ),

                // ✅ INPUT BAR
                Padding(
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
                            controller: _messageController,
                            decoration: const InputDecoration(
                                hintText: "Type your reply...",
                                border: InputBorder.none),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      GestureDetector(
                        onTap: _sendMessage,
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
        ],
      ),
    );
  }

  // ✅ MESSAGE BUBBLE
  Widget _bubble(String text, bool isAuthority) {
    return Align(
      alignment:
          isAuthority ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isAuthority ? const Color(0xFF6EA7A0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style:
              TextStyle(color: isAuthority ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  // ✅ CIRCLE BUTTON
  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
