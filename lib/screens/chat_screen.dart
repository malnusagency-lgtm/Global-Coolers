import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _subscription;
  String? _pickupId;
  String? _myUserId;

  final List<String> _quickReplies = [
    "I'm outside 🚪",
    "5 min away ⏰",
    "Please leave at gate",
    "On my way! 🚛",
    "Almost there!",
    "Ready for pickup ✅",
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pickupId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _pickupId = args?['pickupId']?.toString();
      _myUserId = _supabase.auth.currentUser?.id;
      if (_pickupId != null) _loadAndListenMessages();
    }
  }

  Future<void> _loadAndListenMessages() async {
    // Load existing messages
    try {
      final existing = await _supabase
          .from('messages')
          .select()
          .eq('pickup_id', _pickupId!)
          .order('created_at', ascending: true);
      if (mounted) setState(() => _messages = List<Map<String, dynamic>>.from(existing));
      _scrollToBottom();
    } catch (e) {
      debugPrint('Load messages error: $e');
    }

    // Listen for new messages
    _subscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('pickup_id', _pickupId!)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(data));
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _pickupId == null || _myUserId == null) return;

    _messageController.clear();
    try {
      await _supabase.rpc('send_chat_message', params: {
        'p_pickup_id': _pickupId,
        'p_message': text.trim(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pickup Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Coordinate your pickup', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No messages yet', style: TextStyle(color: AppColors.textSecondary)),
                        const Text('Send a message to coordinate', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _myUserId;
                      return _buildMessageBubble(msg['message'] ?? '', isMe);
                    },
                  ),
          ),

          // Quick Replies
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _sendMessage(_quickReplies[index]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(_quickReplies[index], style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.primaryGradient),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _sendMessage(_messageController.text),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(
          text,
          style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
