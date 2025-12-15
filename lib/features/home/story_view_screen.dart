import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

/// Groups statuses by days (Today, Yesterday, or specific date)
Map<String, List<Map<String, dynamic>>> groupStatusesByDay(List<Map<String, dynamic>> statuses) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  
  for (var status in statuses) {
    final createdAt = DateTime.parse(status['created_at']);
    final statusDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    
    String dayLabel;
    if (statusDate == today) {
      dayLabel = 'Today';
    } else if (statusDate == yesterday) {
      dayLabel = 'Yesterday';
    } else {
      dayLabel = DateFormat('EEEE, MMM d').format(statusDate);
    }
    
    if (!grouped.containsKey(dayLabel)) {
      grouped[dayLabel] = [];
    }
    grouped[dayLabel]!.add(status);
  }
  
  return grouped;
}

/// Returns ordered day keys for display (Today first, then Yesterday, then older dates)
List<String> getOrderedDayKeys(Map<String, List<Map<String, dynamic>>> grouped) {
  final keys = grouped.keys.toList();
  keys.sort((a, b) {
    if (a == 'Today') return -1;
    if (b == 'Today') return 1;
    if (a == 'Yesterday') return -1;
    if (b == 'Yesterday') return 1;
    return b.compareTo(a); // Most recent first
  });
  return keys;
}

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> statuses;
  final String userName;
  final String userAvatar;

  const StoryViewScreen({
    super.key,
    required this.statuses,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // Video player for video statuses
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // Default duration for images/text
  static const Duration _defaultDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this, duration: _defaultDuration);
    
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animController.stop();
        _videoController?.pause();
      } else {
        _animController.forward();
        _videoController?.play();
      }
    });

    _loadCurrentStory();
  }

  Future<void> _loadCurrentStory() async {
    final currentStatus = widget.statuses[_currentIndex];
    final type = currentStatus['type'];
    final contentUrl = currentStatus['content_url'];
    
    // Dispose previous video controller
    await _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    
    if (type == 'video' && contentUrl != null) {
      // Load video and get its duration
      _videoController = VideoPlayerController.networkUrl(Uri.parse(contentUrl));
      
      try {
        await _videoController!.initialize();
        
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          
          // Set animation duration to video duration
          final videoDuration = _videoController!.value.duration;
          _animController.duration = videoDuration;
          
          // Start playing
          _animController.reset();
          _animController.forward();
          _videoController!.play();
        }
      } catch (e) {
        debugPrint("Error initializing video: $e");
        // Fall back to default duration
        _startWithDefaultDuration();
      }
    } else {
      // Image or text - use default 5 second duration
      _startWithDefaultDuration();
    }
  }
  
  void _startWithDefaultDuration() {
    _animController.duration = _defaultDuration;
    _animController.reset();
    _animController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _loadCurrentStory();
    }
  }
  
  void _pauseStory() {
    _animController.stop();
    _videoController?.pause();
  }
  
  void _resumeStory() {
    _animController.forward();
    _videoController?.play();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    
    final currentStatus = widget.statuses[_currentIndex];
    
    try {
        final statusOwnerId = currentStatus['user_id'];
        final myId = SupabaseService.currentUser!.id;
        
        // Find friendship
         final friendshipResponse = await SupabaseService.client.from('friendships')
          .select()
          .or('and(user_id_1.eq.$myId,user_id_2.eq.$statusOwnerId),and(user_id_1.eq.$statusOwnerId,user_id_2.eq.$myId)')
          .limit(1)
          .maybeSingle();

        if (friendshipResponse != null) {
          final friendshipId = friendshipResponse['id'];
          
          await SupabaseService.client.from('messages').insert({
            'friendship_id': friendshipId,
            'sender_id': myId,
            'content': "Replying to status: $text",
            'type': 'text',
          });
          
          if (mounted) {
            _replyController.clear();
            _focusNode.unfocus();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply sent!")));
          }
        }
    } catch (e) {
      debugPrint("Error sending reply: $e");
    }
  }

  Future<void> _likeStatus() async {
     final currentStatus = widget.statuses[_currentIndex];
     try {
        final statusOwnerId = currentStatus['user_id'];
        final myId = SupabaseService.currentUser!.id;
        
         final friendshipResponse = await SupabaseService.client.from('friendships')
          .select()
          .or('and(user_id_1.eq.$myId,user_id_2.eq.$statusOwnerId),and(user_id_1.eq.$statusOwnerId,user_id_2.eq.$myId)')
          .limit(1)
          .maybeSingle();
          
         if (friendshipResponse != null) {
            final friendshipId = friendshipResponse['id'];
             await SupabaseService.client.from('messages').insert({
              'friendship_id': friendshipId,
              'sender_id': myId,
              'content': "❤️ Liked your status",
              'type': 'text',
            });
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liked!")));
         }
     } catch (e) {
       // ignore
     }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _replyController.dispose();
    _focusNode.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) return const SizedBox();
    
    final currentStatus = widget.statuses[_currentIndex];
    final type = currentStatus['type'];
    final contentUrl = currentStatus['content_url'];
    final contentText = currentStatus['content_text'];
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Fixed tap zones: Left 20% = prev, Right 20% = next, Center = nothing
        onTapUp: (details) {
          // Ignore taps on input area
          if (details.globalPosition.dy > screenHeight - 150) {
            return;
          }
          
          final tapX = details.globalPosition.dx;
          if (tapX < screenWidth * 0.2) {
            // Left 20% - previous
            _prevStory();
          } else if (tapX > screenWidth * 0.8) {
            // Right 20% - next
            _nextStory();
          }
          // Center 60% - do nothing (or could show UI)
        },
        onLongPress: _pauseStory,
        onLongPressUp: _resumeStory,
        child: Stack(
          children: [
            // Content
            Center(
              child: _buildContent(type, contentUrl, contentText),
            ),
            
            // Caption
            if (type != 'text' && contentText != null && contentText.toString().isNotEmpty)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    contentText,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Progress Bars
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Row(
                    children: List.generate(widget.statuses.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: LinearProgressIndicator(
                            value: index < _currentIndex
                                ? 1.0
                                : index == _currentIndex
                                    ? _animController.value
                                    : 0.0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            // User Info
            Positioned(
              top: 60,
              left: 20,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(widget.userAvatar),
                    radius: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.userName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Close button
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            
            // Reply & Like
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _replyController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Reply...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: _sendReply,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _likeStatus,
                    icon: const Icon(Icons.favorite_border, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent(String? type, String? contentUrl, String? contentText) {
    if (type == 'video' && contentUrl != null) {
      if (_isVideoInitialized && _videoController != null) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      } else {
        return const CircularProgressIndicator(color: Colors.white);
      }
    } else if (type == 'image' && contentUrl != null) {
      return Image.network(
        contentUrl, 
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const CircularProgressIndicator(color: Colors.white);
        },
      );
    } else {
      // Text status
      return Container(
        color: Colors.purple,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Text(
          contentText ?? "",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }
  }
}
