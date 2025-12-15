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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userId = SupabaseService.currentUser!.id;
    final friendId = _friendProfile?['id'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Status"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _postStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfiles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // My Status Section
              _buildMyStatusSection(userId, isDark),
              
              const Divider(height: 1),
              
              // Friend's Status Section (with day grouping)
              if (friendId != null) _buildFriendStatusSection(friendId, isDark),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _postStatus,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }

  Widget _buildMyStatusSection(String userId, bool isDark) {
    final avatarUrl = _userProfile?['avatar_url'] ?? "";
    final displayName = _userProfile?['display_name'] ?? "Me";

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getFriendStatus(userId),
      builder: (context, snapshot) {
        final myStatuses = snapshot.data ?? [];
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: myStatuses.isNotEmpty ? AppColors.primary : Colors.grey,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).cardColor,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty 
                      ? Icon(Icons.person, color: Theme.of(context).hintColor) 
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          title: Text(
            "My Status",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            myStatuses.isNotEmpty 
                ? "${myStatuses.length} status${myStatuses.length > 1 ? 'es' : ''} • Tap to view"
                : "Tap to add status update",
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          onTap: () {
            if (myStatuses.isNotEmpty) {
              _viewStatuses(myStatuses, displayName, avatarUrl);
            } else {
              _postStatus();
            }
          },
        );
      },
    );
  }

  Widget _buildFriendStatusSection(String friendId, bool isDark) {
    final friendName = _friendProfile?['display_name'] ?? "Friend";
    final friendAvatar = _friendProfile?['avatar_url'] ?? "";

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getFriendStatus(friendId),
      builder: (context, snapshot) {
        final friendStatuses = snapshot.data ?? [];
        
        if (friendStatuses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.photo_camera_outlined, size: 48, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(
                    "No status updates from $friendName",
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
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
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "RECENT UPDATES",
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            // Day groups
            ...orderedDays.map((dayLabel) {
              final statusesForDay = groupedStatuses[dayLabel]!;
              final totalForDay = statusesForDay.length;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header with status count
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: isDark 
                        ? Colors.white.withOpacity(0.03) 
                        : Colors.black.withOpacity(0.02),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dayLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$totalForDay update${totalForDay > 1 ? 's' : ''}",
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Horizontal scroll of status thumbnails for this day
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: statusesForDay.length,
                      itemBuilder: (context, index) {
                        final status = statusesForDay[index];
                        final type = status['type'] ?? 'text';
                        final contentUrl = status['content_url'];
                        final contentText = status['content_text'] ?? '';
                        final time = _formatTime(status['created_at']);
                        
                        return GestureDetector(
                          onTap: () {
                            // Start viewing from this status
                            _viewStatuses(
                              statusesForDay.sublist(index), 
                              friendName, 
                              friendAvatar,
                            );
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: type == 'text' 
                                        ? AppColors.primaryGradient 
                                        : null,
                                    image: type == 'image' && contentUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(contentUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: type == 'video' ? Colors.grey[800] : null,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: type == 'video'
                                      ? const Icon(Icons.play_circle, color: Colors.white)
                                      : type == 'text'
                                          ? Center(
                                              child: Text(
                                                contentText.length > 6 
                                                    ? '${contentText.substring(0, 6)}...'
                                                    : contentText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
