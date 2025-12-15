import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  
  // Selected messages for multi-select
  final Set<String> _selectedMessageIds = {};
  bool _isSelecting = false;
  
  @override
  void initState() {
    super.initState();
    _friendshipId = widget.friendshipId;
    if (_friendshipId == null) {
      _fetchFriendshipId();
    } else {
      _fetchFriendDetails();
    }
  }

  Future<void> _fetchFriendshipId() async {
    final id = await SupabaseService.getActiveFriendshipId();
    if (mounted) {
      setState(() => _friendshipId = id);
      if (id != null) _fetchFriendDetails();
    }
  }

  Future<void> _fetchFriendDetails() async {
    if (_friendshipId == null) return;
    try {
      final details = await SupabaseService.getFriendDetails(_friendshipId!);
      if (mounted) setState(() => _friendProfile = details);
    } catch (e) {
      debugPrint("Error fetching friend details: $e");
    }
  }

  void _handleCall(bool isVideo) {
    if (_friendProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend profile not loaded yet.")),
      );
      return;
    }
    final friendId = _friendProfile!['id'];
    if (friendId == null || friendId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot call: Friend ID missing.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          friendName: _friendProfile!['display_name'] ?? "Friend",
          friendAvatar: _friendProfile!['avatar_url'] ?? "",
          isVideo: isVideo,
          friendId: friendId.toString(),
        ),
      ),
    );
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ChatSettingsSheet(friendshipId: _friendshipId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUser?.id;
    final friendName = _friendProfile?['display_name'] ?? "Friend";
    final friendAvatar = _friendProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=33";
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _isSelecting ? _buildSelectionAppBar() : _buildNormalAppBar(friendName, friendAvatar),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _friendshipId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: SupabaseService.client
                          .from('messages')
                          .stream(primaryKey: ['id'])
                          .eq('friendship_id', _friendshipId!)
                          .order('created_at'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        
                        final allMessages = snapshot.data ?? [];
                        
                        // Filter messages
                        final messages = allMessages
                            .where((m) => _shouldShowMessage(m))
                            .toList();
                        
                        // Sort newest first for reversed list
                        messages.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
                        
                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Theme.of(context).hintColor),
                                const SizedBox(height: 16),
                                Text(
                                  "No messages yet",
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Say hi to $friendName!",
                                  style: TextStyle(color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Build grouped list with date headers
                        final groupedItems = _buildGroupedMessages(messages);
                        
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: groupedItems.length,
                          itemBuilder: (context, index) {
                            final item = groupedItems[index];
                            
                            if (item['type'] == 'date_header') {
                              return _buildDateHeader(item['date'] as String);
                            }
                            
                            final msg = item['message'] as Map<String, dynamic>;
                            final isMe = msg['sender_id'] == myId;
                            final isSelected = _selectedMessageIds.contains(msg['id']);
                            
                            return _buildMessageItem(msg, isMe, isSelected);
                          },
                        );
                      },
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildGroupedMessages(List<Map<String, dynamic>> messages) {
    final List<Map<String, dynamic>> result = [];
    String? currentDateStr;
    
    for (final msg in messages) {
      final createdAt = DateTime.parse(msg['created_at']);
      final dateStr = _formatDateHeader(createdAt);
      
      // Add message first (since list is reversed)
      result.add({'type': 'message', 'message': msg});
      
      // Add date header if date changed
      if (dateStr != currentDateStr) {
        result.add({'type': 'date_header', 'date': dateStr});
        currentDateStr = dateStr;
      }
    }
    
    return result;
  }

  AppBar _buildNormalAppBar(String friendName, String friendAvatar) {
    return AppBar(
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(friendAvatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friendName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  "Online",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => _handleCall(false)),
        IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () => _handleCall(true)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'settings') _showChatSettings();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'settings', child: Text('Chat Settings')),
          ],
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _isSelecting = false;
            _selectedMessageIds.clear();
          });
        },
      ),
      title: Text("${_selectedMessageIds.length} selected"),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _showDeleteOptions,
        ),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Widget _buildDateHeader(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            date,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg, bool isMe, bool isSelected) {
    final content = msg['content'] ?? "";
    final type = msg['type'] ?? 'text';
    final createdAt = DateTime.parse(msg['created_at']);
    final time = DateFormat('h:mm a').format(createdAt);
    
    Widget messageContent;
    
    switch (type) {
      case 'image':
        messageContent = _buildImageMessage(msg, isMe, time);
        break;
      case 'video':
        messageContent = _buildVideoMessage(msg, isMe, time);
        break;
      case 'file':
        messageContent = _buildFileMessage(msg, isMe, time);
        break;
      case 'nudge':
        messageContent = _buildNudgeMessage(isMe, time);
        break;
      default:
        messageContent = _buildTextMessage(content, isMe, time);
    }
    
    return GestureDetector(
      onLongPress: () => _onMessageLongPress(msg),
      onTap: _isSelecting ? () => _toggleMessageSelection(msg['id']) : null,
      child: Container(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: messageContent,
        ),
      ),
    );
  }

  Widget _buildTextMessage(String content, bool isMe, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      decoration: BoxDecoration(
        gradient: isMe ? (isDark ? AppColors.darkPrimaryGradient : AppColors.primaryGradient) : null,
        color: isMe ? null : AppColors.getMessageBubbleColor(context, false),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: isMe 
                ? AppColors.primary.withOpacity(0.2)
                : Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            content, 
            style: TextStyle(
              color: AppColors.getMessageTextColor(context, isMe),
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time, 
                style: TextStyle(
                  color: AppColors.getMessageTimeColor(context, isMe),
                  fontSize: 10,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeMessage(bool isMe, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.back_hand, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            isMe ? "You sent a nudge" : "Nudge! 👋",
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> msg, bool isMe, String time) {
    final url = msg['content'];
    final isOneTime = msg['is_one_time'] == true;
    final isViewed = msg['one_time_viewed'] == true;
    
    if (isOneTime && isViewed && !isMe) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () {
        if (isOneTime && !isMe && !isViewed) {
          _viewOneTimeMedia(url, 'image', msg['id']);
        } else if (!isOneTime || isMe) {
          _showFullImage(url);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65, maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              isOneTime && !isMe && !isViewed
                  ? Container(
                      height: 150,
                      width: 180,
                      color: Colors.grey[800],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility, color: Colors.white, size: 36),
                          SizedBox(height: 8),
                          Text('View once', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 150,
                          width: 180,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: 180,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40),
                        );
                      },
                    ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              if (isOneTime)
                const Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(Icons.timelapse, color: Colors.white70, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(Map<String, dynamic> msg, bool isMe, String time) {
    final url = msg['content'];
    final isOneTime = msg['is_one_time'] == true;
    final isViewed = msg['one_time_viewed'] == true;
    
    if (isOneTime && isViewed && !isMe) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () {
        if (isOneTime && !isMe && !isViewed) {
          _viewOneTimeMedia(url, 'video', msg['id']);
        } else if (!isOneTime || isMe) {
          _playVideo(url);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 160,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
            if (isOneTime)
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.timelapse, color: Colors.white70, size: 18),
              ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> msg, bool isMe, String time) {
    final fileName = msg['file_name'] ?? 'Document';
    final fileSize = msg['file_size'] ?? 0;
    
    return GestureDetector(
      onTap: () => _downloadAndOpenFile(msg['content'], fileName),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacity(0.8) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_drive_file, color: isMe ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(color: isMe ? Colors.white : null, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(color: isMe ? Colors.white70 : Theme.of(context).hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
                size: 26,
              ),
              onPressed: _showAttachmentMenu,
            ),
            // Text input field
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                maxLines: 5,
                minLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMessageLongPress(Map<String, dynamic> msg) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelecting = true;
      _selectedMessageIds.add(msg['id']);
    });
  }

  void _toggleMessageSelection(String id) {
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
        if (_selectedMessageIds.isEmpty) _isSelecting = false;
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  void _showDeleteOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessages(forEveryone: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete for everyone'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessages(forEveryone: true);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessages({required bool forEveryone}) async {
    try {
      for (final id in _selectedMessageIds) {
        await SupabaseService.client.from('messages').delete().eq('id', id);
      }
      
      setState(() {
        _isSelecting = false;
        _selectedMessageIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message(s) deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  bool _shouldShowMessage(Map<String, dynamic> msg) {
    if (msg['expires_at'] != null) {
      final expiresAt = DateTime.parse(msg['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) return false;
    }
    if (msg['is_one_time'] == true && 
        msg['one_time_viewed'] == true && 
        msg['sender_id'] != SupabaseService.currentUser?.id) {
      return false;
    }
    return true;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    _controller.clear();
    
    final friendshipId = _friendshipId;
    if (friendshipId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active friendship found.")),
        );
      }
      return;
    }
    
    try {
      await SupabaseService.client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': SupabaseService.currentUser!.id,
        'content': text,
        'type': 'text',
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send: ${e.toString()}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send Attachment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(Icons.photo, 'Photo', Colors.purple, () => _pickMedia('image', false)),
                _buildAttachmentOption(Icons.videocam, 'Video', Colors.blue, () => _pickMedia('video', false)),
                _buildAttachmentOption(Icons.insert_drive_file, 'File', Colors.orange, _pickFile),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(Icons.camera_alt, 'Camera', Colors.pink, () => _pickFromCamera()),
                _buildAttachmentOption(Icons.visibility_off, 'View Once', Colors.teal, () => _pickMedia('image', true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    
    if (file != null && _friendshipId != null) {
      try {
        await SupabaseService.sendImageMessage(_friendshipId!, File(file.path));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _pickMedia(String type, bool isOneTime) async {
    final picker = ImagePicker();
    XFile? file;
    
    if (type == 'image') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }
    
    if (file != null && _friendshipId != null) {
      try {
        if (type == 'image') {
          await SupabaseService.sendImageMessage(_friendshipId!, File(file.path), isOneTime: isOneTime);
        } else {
          await SupabaseService.sendVideoMessage(_friendshipId!, File(file.path), isOneTime: isOneTime);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null && _friendshipId != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      try {
        await SupabaseService.sendFileMessage(_friendshipId!, file, fileName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullImageScreen(url: url)),
    );
  }

  Future<void> _viewOneTimeMedia(String url, String type, String messageId) async {
    await SupabaseService.markOneTimeViewed(messageId);
    
    if (type == 'image') {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => _OneTimeImageScreen(url: url)));
      }
    } else {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url)));
      }
    }
  }

  void _playVideo(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url)));
  }

  Future<void> _downloadAndOpenFile(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

// Chat Settings Sheet
class _ChatSettingsSheet extends StatefulWidget {
  final String friendshipId;
  const _ChatSettingsSheet({required this.friendshipId});

  @override
  State<_ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<_ChatSettingsSheet> {
  String _disappearingMode = 'off';
  int _customHours = 24;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SupabaseService.getChatSettings(widget.friendshipId);
      if (settings != null && mounted) {
        setState(() {
          _disappearingMode = settings['disappearing_mode'] ?? 'off';
          _customHours = settings['custom_duration_hours'] ?? 24;
        });
      }
    } catch (e) {
      debugPrint("Error loading chat settings: $e");
    }
  }

  Future<void> _saveSettings() async {
    try {
      await SupabaseService.updateChatSettings(
        widget.friendshipId,
        _disappearingMode,
        customHours: _disappearingMode == 'custom' ? _customHours : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Disappearing Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          RadioListTile<String>(
            value: 'off',
            groupValue: _disappearingMode,
            onChanged: (v) => setState(() => _disappearingMode = v!),
            title: const Text('Off'),
          ),
          RadioListTile<String>(
            value: '1_week',
            groupValue: _disappearingMode,
            onChanged: (v) => setState(() => _disappearingMode = v!),
            title: const Text('1 Week'),
          ),
          RadioListTile<String>(
            value: 'custom',
            groupValue: _disappearingMode,
            onChanged: (v) => setState(() => _disappearingMode = v!),
            title: const Text('Custom'),
          ),
          if (_disappearingMode == 'custom')
            Slider(
              value: _customHours.toDouble(),
              min: 1,
              max: 168,
              divisions: 167,
              label: '$_customHours hours',
              onChanged: (v) => setState(() => _customHours = v.toInt()),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// Full Image Screen
class _FullImageScreen extends StatelessWidget {
  final String url;
  const _FullImageScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}

// One-Time Image Screen
class _OneTimeImageScreen extends StatelessWidget {
  final String url;
  const _OneTimeImageScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: Image.network(url)),
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Text(
                'This image will disappear after viewing',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Video Player Screen
class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  const _VideoPlayerScreen({required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
