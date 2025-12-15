import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? friendshipId;
  const ChatScreen({super.key, this.friendshipId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _friendshipId;
  Map<String, dynamic>? _friendProfile;
  
  // Optimistic messages list (instant UI updates)
  final List<Map<String, dynamic>> _optimisticMessages = [];
  StreamSubscription? _messagesSubscription;
  
  @override
  void initState() {
    super.initState();
    _friendshipId = widget.friendshipId;
    if (_friendshipId == null) {
      _fetchFriendshipId();
    } else {
      _fetchFriendDetails();
      _subscribeToMessages();
    }
  }
  
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchFriendshipId() async {
    final id = await SupabaseService.getActiveFriendshipId();
    if (mounted) {
      setState(() => _friendshipId = id);
      if (id != null) {
        _fetchFriendDetails();
        _subscribeToMessages();
      }
    }
  }

  Future<void> _fetchFriendDetails() async {
    if (_friendshipId == null) return;
    try {
      final details = await SupabaseService.getFriendDetails(_friendshipId!);
      if (mounted) setState(() => _friendProfile = details);
    } catch (e) {
      debugPrint(\"Error fetching friend details: $e\");
    }
  }
  
  void _subscribeToMessages() {
    if (_friendshipId == null) return;
    _messagesSubscription?.cancel();
    // No need to store in state - StreamBuilder handles it
  }

  void _handleCall(bool isVideo) {
    if (_friendProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(\"Friend profile not loaded yet.\")),
      );
      return;
    }
    final friendId = _friendProfile!['id'];
    if (friendId == null || friendId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(\"Cannot call: Friend ID missing.\")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          friendName: _friendProfile!['display_name'] ?? \"Friend\",
          friendAvatar: _friendProfile!['avatar_url'] ?? \"\",
          isVideo: isVideo,
          friendId: friendId.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUser?.id;
    final friendName = _friendProfile?['display_name'] ?? \"Friend\";
    final friendAvatar = _friendProfile?['avatar_url'] ?? \"https://i.pravatar.cc/150?img=33\";
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(friendName, friendAvatar),
      body: Column(
        children: [
          Expanded(
            child: _friendshipId == null
                ? const Center(child: CircularProgressIndicator())
                : _buildMessagesList(myId),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar(String friendName, String friendAvatar) {
    return AppBar(
      backgroundColor: AppColors.getSurface(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(friendAvatar),
            backgroundColor: AppColors.getDivider(context),
          ),
          const SizedBox(width: 12),
          Text(
            friendName,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.call, color: AppColors.primary),
          onPressed: () => _handleCall(false),
        ),
        IconButton(
          icon: Icon(Icons.videocam, color: AppColors.primary),
          onPressed: () => _handleCall(true),
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: AppColors.getTextSecondary(context)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessagesList(String? myId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('friendship_id', _friendshipId!)
          .order('created_at')
          .map((maps) => maps),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Combine server messages with optimistic messages
        final serverMessages = snapshot.data!
            .where((m) => _shouldShowMessage(m))
            .toList();
        
        final allMessages = [...serverMessages, ..._optimisticMessages];
        allMessages.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
        
        // Auto-scroll to bottom when new message arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && allMessages.isNotEmpty) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
        
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: allMessages.length,
          itemBuilder: (context, index) {
            final msg = allMessages[index];
            final isMe = msg['sender_id'] == myId;
            final isOptimistic = msg['_optimistic'] == true;
            
            return _buildMessageBubble(msg, isMe, isOptimistic)
                .animate(key: ValueKey(msg['id']))
                .fadeIn(duration: 200.ms)
                .slideY(begin: 0.1, end: 0, duration: 200.ms);
          },
        );
      },
    );
  }

  bool _shouldShowMessage(Map<String, dynamic> msg) {
    // Hide expired messages
    if (msg['expires_at'] != null) {
      final expiresAt = DateTime.parse(msg['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) return false;
    }
    // Hide one-time viewed messages
    if (msg['is_one_time'] == true && 
        msg['one_time_viewed'] == true && 
        msg['sender_id'] != SupabaseService.currentUser?.id) {
      return false;
    }
    return true;
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool isOptimistic) {
    final type = msg['type'] ?? 'text';
    final content = msg['content'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final time = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe 
              ? AppColors.getSentBubble(context)
              : AppColors.getReceivedBubble(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (type == 'text')
              Text(
                content,
                style: TextStyle(
                  color: isMe 
                      ? AppColors.getSentText(context)
                      : AppColors.getReceivedText(context),
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe 
                        ? AppColors.getSentText(context).withValues(alpha: 0.7)
                        : AppColors.getReceivedText(context).withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isOptimistic ? Icons.schedule : Icons.done_all,
                    size: 14,
                    color: AppColors.getSentText(context).withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    _controller.clear();
    
    // Create optimistic message
    final optimisticId = const Uuid().v4();
    final optimisticMessage = {
      'id': optimisticId,
      'friendship_id': _friendshipId,
      'sender_id': SupabaseService.currentUser!.id,
      'content': text,
      'type': 'text',
      'created_at': DateTime.now().toIso8601String(),
      '_optimistic': true,
    };
    
    
    // Add to optimistic list for instant UI update
    setState(() {
      _optimisticMessages.add(optimisticMessage);
    });
    
    try {
      String? friendshipId = _friendshipId ?? await SupabaseService.getActiveFriendshipId();
      if (friendshipId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(\"No active friendship found.\")),
          );
        }
        // Remove optimistic message
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
        return;
      }
      
      if (_friendshipId == null && mounted) {
        setState(() => _friendshipId = friendshipId);
      }
      
      // Get expiry time
      final expiresAt = await SupabaseService.getMessageExpiryTime(friendshipId);
      
      // Send to server
      await SupabaseService.client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': SupabaseService.currentUser!.id,
        'content': text,
        'type': 'text',
        'expires_at': expiresAt?.toIso8601String(),
      });
      
      // Remove optimistic message (real one will come from stream)
      setState(() {
        _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
      });
    } catch (e) {
      debugPrint(\"Error sending: $e\");
      // Remove optimistic message on error
      setState(() {
        _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(\"Failed to send: $e\")),
        );
      }
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(
          top: BorderSide(
            color: AppColors.getDivider(context),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Plus button for attachments
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary, size: 24),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: \"Message...\",
                    hintStyle: TextStyle(
                      color: AppColors.getTextSecondary(context),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
