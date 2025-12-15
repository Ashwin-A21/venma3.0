import 'package:flutter/material.dart';
import '../../core/extensions/color_extensions.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
  String? _friendshipId;
  Map<String, dynamic>? _friendProfile;
  bool _showAttachmentOptions = false;
  
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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(friendAvatar),
            ),
            const SizedBox(width: 10),
            Text(friendName),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () => _handleCall(false)),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () => _handleCall(true)),
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _friendshipId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Map<String, dynamic>>>(
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
                      final messages = snapshot.data!
                          .where((m) => _shouldShowMessage(m))
                          .toList();
                      messages.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
                      
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return _buildMessageBubble(msg, msg['sender_id'] == myId);
                        },
                      );
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  bool _shouldShowMessage(Map<String, dynamic> msg) {
    // Hide expired messages
    if (msg['expires_at'] != null) {
      final expiresAt = DateTime.parse(msg['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) return false;
    }
    // Hide one-time viewed messages (for receiver)
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
    
    try {
      String? friendshipId = _friendshipId ?? await SupabaseService.getActiveFriendshipId();
      if (friendshipId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No active friendship found.")),
          );
        }
        return;
      }
      
      if (_friendshipId == null && mounted) {
        setState(() => _friendshipId = friendshipId);
      }
      
      // Get expiry time based on chat settings
      final expiresAt = await SupabaseService.getMessageExpiryTime(friendshipId);
      
      await SupabaseService.client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': SupabaseService.currentUser!.id,
        'content': text,
        'type': 'text',
        'expires_at': expiresAt?.toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error sending: $e");
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
                _buildAttachOption(Icons.image, 'Image', Colors.purple, () => _pickMedia('image', false)),
                _buildAttachOption(Icons.videocam, 'Video', Colors.red, () => _pickMedia('video', false)),
                _buildAttachOption(Icons.insert_drive_file, 'File', Colors.blue, _pickFile),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('One-time view (disappears after viewing)', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachOption(Icons.photo_camera, 'One-time\nImage', Colors.orange, () => _pickMedia('image', true)),
                _buildAttachOption(Icons.video_camera_back, 'One-time\nVideo', Colors.pink, () => _pickMedia('video', true)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachOption(IconData icon, String label, Color color, VoidCallback onTap) {
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
              color: color.withOpacityValue(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickMedia(String type, bool isOneTime) async {
    final picker = ImagePicker();
    XFile? file;
    
    if (type == 'image') {
      file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }
    
    if (file != null && _friendshipId != null) {
      _showUploadProgress(type == 'image' ? 'image' : 'video');
      try {
        if (type == 'image') {
          await SupabaseService.sendImageMessage(_friendshipId!, File(file.path), isOneTime: isOneTime);
        } else {
          await SupabaseService.sendVideoMessage(_friendshipId!, File(file.path), isOneTime: isOneTime);
        }
        _hideUploadProgress(true);
      } catch (e) {
        _hideUploadProgress(false, error: e.toString());
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null && _friendshipId != null) {
      _showUploadProgress('file');
      try {
        await SupabaseService.sendFileMessage(
          _friendshipId!,
          File(result.files.single.path!),
          result.files.single.name,
        );
        _hideUploadProgress(true);
      } catch (e) {
        _hideUploadProgress(false, error: e.toString());
      }
    }
  }

  void _showUploadProgress(String type) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Text('Sending $type...'),
            ],
          ),
          duration: const Duration(seconds: 60),
        ),
      );
    }
  }

  void _hideUploadProgress(bool success, {String? error}) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Sent!' : 'Error: $error'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] ?? 'text';
    final content = msg['content'] ?? '';
    final isOneTime = msg['is_one_time'] == true;
    final messageId = msg['id'];
    
    // Parse time
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final time = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    
    Widget messageContent;
    
    switch (type) {
      case 'image':
        messageContent = _buildImageMessage(content, isMe, time, isOneTime, messageId);
        break;
      case 'video':
        messageContent = _buildVideoMessage(content, isMe, time, isOneTime, messageId);
        break;
      case 'file':
        messageContent = _buildFileMessage(msg, isMe, time);
        break;
      default:
        messageContent = _buildTextMessage(content, isMe, time);
    }
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: messageContent,
    );
  }

  Widget _buildTextMessage(String content, bool isMe, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.primaryGradient : null,
        color: isMe ? null : Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(content, style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildImageMessage(String url, bool isMe, String time, bool isOneTime, String messageId) {
    return GestureDetector(
      onTap: () {
        if (isOneTime && !isMe) {
          _viewOneTimeMedia(url, 'image', messageId);
        } else {
          _showFullImage(url);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7, maxHeight: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isMe ? AppColors.primary : Colors.grey.withOpacityValue(0.3)),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: isOneTime && !isMe
                  ? Container(
                      height: 150,
                      width: 200,
                      color: Colors.grey[800],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_off, color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text('Tap to view once', style: TextStyle(color: Colors.white)),
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
                          width: 200,
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, _) => Container(
                        height: 100,
                        width: 200,
                        color: Colors.grey[800],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
            ),
            if (isOneTime)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMessage(String url, bool isMe, String time, bool isOneTime, String messageId) {
    return GestureDetector(
      onTap: () {
        if (isOneTime && !isMe) {
          _viewOneTimeMedia(url, 'video', messageId);
        } else {
          _playVideo(url);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.grey[800],
          border: Border.all(color: isMe ? AppColors.primary : Colors.grey.withOpacityValue(0.3)),
        ),
        child: Stack(
          children: [
            Container(
              height: 150,
              width: 200,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isOneTime && !isMe ? Icons.visibility_off : Icons.play_circle_fill, 
                       color: Colors.white, size: 50),
                  const SizedBox(height: 8),
                  Text(isOneTime && !isMe ? 'Tap to view once' : 'Video', 
                       style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            if (isOneTime)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> msg, bool isMe, String time) {
    final fileName = msg['file_name'] ?? 'File';
    final fileSize = msg['file_size'] ?? 0;
    final sizeStr = fileSize > 1024 * 1024 
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(1)} KB';
    
    return GestureDetector(
      onTap: () => _downloadAndOpenFile(msg['content'], fileName),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacityValue(0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isMe ? AppColors.primary : Colors.grey.withOpacityValue(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacityValue(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(sizeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _viewOneTimeMedia(String url, String type, String messageId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OneTimeMediaViewer(
        url: url,
        type: type,
        onClose: () async {
          await SupabaseService.markOneTimeViewed(messageId);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  void _playVideo(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url)),
    );
  }

  Future<void> _downloadAndOpenFile(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: _showAttachmentMenu,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: "Message...",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.grey),
              onPressed: () => _pickMedia('image', false),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
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
  String _mode = 'off';
  int _customHours = 24;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SupabaseService.getChatSettings(widget.friendshipId);
    if (mounted) {
      setState(() {
        _mode = settings?['disappearing_mode'] ?? 'off';
        _customHours = settings?['custom_duration_hours'] ?? 24;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await SupabaseService.updateChatSettings(widget.friendshipId, _mode, customHours: _customHours);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Disappearing Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Messages will automatically delete based on your selection.', 
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text('Off'),
                  value: 'off',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Delete after read'),
                  value: 'after_read',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                RadioListTile<String>(
                  title: const Text('1 Week'),
                  value: '1_week',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Custom'),
                  value: 'custom',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                if (_mode == 'custom') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Duration: '),
                      Expanded(
                        child: Slider(
                          value: _customHours.toDouble(),
                          min: 1,
                          max: 168,
                          divisions: 167,
                          label: _customHours <= 24 ? '$_customHours hours' : '${(_customHours / 24).round()} days',
                          onChanged: (v) => setState(() => _customHours = v.round()),
                        ),
                      ),
                      Text(_customHours <= 24 ? '$_customHours h' : '${(_customHours / 24).round()} d'),
                    ],
                  ),
                ],
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

// One-time media viewer
class _OneTimeMediaViewer extends StatefulWidget {
  final String url;
  final String type;
  final VoidCallback onClose;

  const _OneTimeMediaViewer({required this.url, required this.type, required this.onClose});

  @override
  State<_OneTimeMediaViewer> createState() => _OneTimeMediaViewerState();
}

class _OneTimeMediaViewerState extends State<_OneTimeMediaViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController?.play();
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: widget.onClose,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.type == 'image')
              InteractiveViewer(child: Image.network(widget.url))
            else if (_videoController?.value.isInitialized == true)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            const Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Text(
                'Tap anywhere to close\nThis will not be viewable again',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
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
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    Center(
                      child: IconButton(
                        iconSize: 60,
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
