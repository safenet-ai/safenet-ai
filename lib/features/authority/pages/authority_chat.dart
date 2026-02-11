import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthorityChatPage extends StatefulWidget {
  final String conversationId;
  final String userName;
  final String userType; // "resident", "worker", or "security"

  const AuthorityChatPage({
    super.key,
    required this.conversationId,
    required this.userName,
    this.userType = "resident",
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

    final chatCollection = widget.userType == "worker"
        ? "worker_support_chats"
        : widget.userType == "security"
        ? "security_support_chats"
        : "support_chats";

    await FirebaseFirestore.instance
        .collection(chatCollection)
        .doc(widget.conversationId)
        .collection("messages")
        .add({
          "sender": "authority",
          "text": text,
          "timestamp": FieldValue.serverTimestamp(),
        });

    // Notify recipient
    try {
      final requestCollection = widget.userType == "worker"
          ? "worker_support_requests"
          : widget.userType == "security"
          ? "security_support_requests"
          : "support_requests";
          
      final requestDoc = await FirebaseFirestore.instance
          .collection(requestCollection)
          .doc(widget.conversationId)
          .get();
          
      if (requestDoc.exists) {
        String? targetUid;
        if (widget.userType == "worker") {
          targetUid = requestDoc.data()?["workerId"];
        } else if (widget.userType == "security") {
          targetUid = requestDoc.data()?["securityId"];
        } else {
          targetUid = requestDoc.data()?["residentId"];
        }
        
        if (targetUid != null) {
          await NotificationService.sendNotification(
            userId: targetUid,
            userRole: widget.userType == "resident" ? "user" : widget.userType,
            title: "New Message from Authority",
            body: text,
            type: "chat_message",
            additionalData: {"conversationId": widget.conversationId},
          );
        }
      }
    } catch (e) {
      print("Error sending chat notification: $e");
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

  // ✅ END CHAT SESSION
  Future<void> _endChat() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("End Chat Session"),
        content: const Text(
          "Are you sure you want to end this chat session? This will close the connection and delete the chat history.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("End Chat"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final chatCollection = widget.userType == "worker"
          ? "worker_support_chats"
          : widget.userType == "security"
          ? "security_support_chats"
          : "support_chats";
      final requestCollection = widget.userType == "worker"
          ? "worker_support_requests"
          : widget.userType == "security"
          ? "security_support_requests"
          : "support_requests";

      // Delete all messages in the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection(chatCollection)
          .doc(widget.conversationId)
          .collection("messages")
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the chat document
      await FirebaseFirestore.instance
          .collection(chatCollection)
          .doc(widget.conversationId)
          .delete();

      // Delete the request
      await FirebaseFirestore.instance
          .collection(requestCollection)
          .doc(widget.conversationId)
          .delete();

      print("✅ Chat session ended and deleted");

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Error ending chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error ending chat: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
          ),

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
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),

                      Column(
                        children: [
                          const Text(
                            "Authority Support",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Chat with ${widget.userName}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      _circleButton(
                        Icons.close,
                        onTap: _endChat,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ STATUS CHIP
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Connected to ${widget.userType == "worker"
                        ? "Worker"
                        : widget.userType == "security"
                        ? "Security"
                        : "Resident"}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ CHAT STREAM
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(
                          widget.userType == "worker"
                              ? "worker_support_chats"
                              : widget.userType == "security"
                              ? "security_support_chats"
                              : "support_chats",
                        )
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

                          final isAuthority = data["sender"] == "authority";

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
                              border: InputBorder.none,
                            ),
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
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
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
      alignment: isAuthority ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAuthority ? const Color(0xFF6EA7A0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(color: isAuthority ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  // ✅ CIRCLE BUTTON
  Widget _circleButton(IconData icon, {VoidCallback? onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color?.withOpacity(0.15) ?? Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
