import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import 'story_view_screen.dart';
import 'status_screen.dart';

class StatusListScreen extends StatefulWidget {
  final String? friendshipId;
  
  const StatusListScreen({super.key, this.friendshipId});

  @override
  State<StatusListScreen> createState() => _StatusListScreenState();
}

class _StatusListScreenState extends State<StatusListScreen> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _friendProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    try {
      final userId = SupabaseService.currentUser!.id;
      _userProfile = await SupabaseService.getUserProfile(userId);
      
      if (widget.friendshipId != null) {
        _friendProfile = await SupabaseService.getFriendDetails(widget.friendshipId!);
      }
    } catch (e) {
      debugPrint("Error fetching profiles: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Groups statuses by days (Today, Yesterday, or specific date)
  Map<String, List<Map<String, dynamic>>> _groupStatusesByDay(List<Map<String, dynamic>> statuses) {
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

  /// Returns ordered day keys for display (Today first, then Yesterday, then older)
  List<String> _getOrderedDayKeys(Map<String, List<Map<String, dynamic>>> grouped) {
    final keys = grouped.keys.toList();
    keys.sort((a, b) {
      if (a == 'Today') return -1;
      if (b == 'Today') return 1;
      if (a == 'Yesterday') return -1;
      if (b == 'Yesterday') return 1;
      return b.compareTo(a);
    });
    return keys;
  }

  String _formatTime(String createdAt) {
    final date = DateTime.parse(createdAt);
    return DateFormat('h:mm a').format(date);
  }

  void _viewStatuses(List<Map<String, dynamic>> statuses, String userName, String avatarUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(
          statuses: statuses,
          userName: userName,
          userAvatar: avatarUrl,
        ),
      ),
    );
  }

  void _postStatus() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userId = SupabaseService.currentUser!.id;
    final friendId = _friendProfile?['id'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Status"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: _postStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Status Section
            _buildMyStatusSection(userId),
            
            const SizedBox(height: 20),
            
            // Friend's Status Section (with day grouping)
            if (friendId != null) _buildFriendStatusSection(friendId),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _postStatus,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }

  Widget _buildMyStatusSection(String userId) {
    final avatarUrl = _userProfile?['avatar_url'] ?? "";
    final displayName = _userProfile?['display_name'] ?? "Me";

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getFriendStatus(userId),
      builder: (context, snapshot) {
        final myStatuses = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "My Status",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: myStatuses.isNotEmpty ? AppColors.primary : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty 
                          ? const Icon(Icons.person, color: Colors.white) 
                          : null,
                    ),
                  ),
                  if (myStatuses.isEmpty)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                myStatuses.isNotEmpty 
                    ? "${myStatuses.length} status${myStatuses.length > 1 ? 'es' : ''}"
                    : "Tap to add status",
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  _viewStatuses(myStatuses, displayName, avatarUrl);
                } else {
                  _postStatus();
                }
              },
              onLongPress: _postStatus,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendStatusSection(String friendId) {
    final friendName = _friendProfile?['display_name'] ?? "Friend";
    final friendAvatar = _friendProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=33";

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getFriendStatus(friendId),
      builder: (context, snapshot) {
        final friendStatuses = snapshot.data ?? [];
        
        if (friendStatuses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                "No friend statuses yet",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Group statuses by day
        final groupedStatuses = _groupStatusesByDay(friendStatuses);
        final orderedDays = _getOrderedDayKeys(groupedStatuses);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Friend's Status",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...orderedDays.map((dayLabel) {
              final statusesForDay = groupedStatuses[dayLabel]!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.black12,
                    child: Text(
                      dayLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  // Status items for this day
                  ...statusesForDay.map((status) {
                    final type = status['type'] ?? 'text';
                    final contentText = status['content_text'] ?? '';
                    final createdAt = status['created_at'];
                    
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: friendAvatar.isNotEmpty 
                                ? NetworkImage(friendAvatar) 
                                : null,
                            child: friendAvatar.isEmpty 
                                ? const Icon(Icons.person, color: Colors.white) 
                                : null,
                          ),
                        ),
                      ),
                      title: Text(
                        friendName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            type == 'image' 
                                ? Icons.image 
                                : type == 'video' 
                                    ? Icons.videocam 
                                    : Icons.text_fields,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              type == 'text' 
                                  ? (contentText.length > 30 
                                      ? '${contentText.substring(0, 30)}...' 
                                      : contentText)
                                  : type == 'image' 
                                      ? 'Photo' 
                                      : 'Video',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        _formatTime(createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        // View just this day's statuses or all statuses starting from this one
                        _viewStatuses(statusesForDay, friendName, friendAvatar);
                      },
                    );
                  }),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
