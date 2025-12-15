import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../onboarding/search_user_screen.dart';
import '../profile/user_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/call_screen.dart';
import '../chat/incoming_call_screen.dart';
import '../camera/camera_screen.dart';
import '../settings/settings_screen.dart';
import 'status_screen.dart';
import 'status_list_screen.dart';
import 'story_view_screen.dart';
import 'flipping_avatar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  String? _activeFriendshipId;
  bool _isLoading = true;

  StreamSubscription? _callSubscription;
  StreamSubscription? _messageSubscription;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _checkFriendshipStatus();
    _checkFriendshipStatus();
    _listenForCalls();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  void _listenForMessages(String friendshipId) {
    _messageSubscription?.cancel();
    _messageSubscription = SupabaseService.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('friendship_id', friendshipId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((messages) async {
          if (messages.isNotEmpty) {
            final msg = messages.first;
            final isNotMe = msg['sender_id'] != SupabaseService.currentUser!.id;
            final createdAt = DateTime.parse(msg['created_at']);
            final isRecent = DateTime.now().difference(createdAt).inSeconds < 10;

            if (isNotMe && isRecent) {
              if (msg['type'] == 'nudge') {
                // Vibration handled in HomeDashboard, but good to have notification too
                 _showNotification("Nudge!", "Someone sent you a nudge.");
                 if (await Vibration.hasVibrator() ?? false) {
                   Vibration.vibrate(pattern: [0, 500, 100, 500]);
                 }
              } else {
                 _showNotification("New Message", msg['content'] ?? "Sent a media file");
              }
            }
          }
        });
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'Venma Messages',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(0, title, body, details);
  }

  void _listenForCalls() {
    _callSubscription = SupabaseService.listenForIncomingCalls().listen((calls) {
      if (calls.isNotEmpty) {
        final call = calls.last;
        // Check if we are already in a call to avoid multiple screens
        // For simplicity, just push.
        if (mounted) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)));
        }
      }
    });
  }
  
  @override
  void dispose() {
    _callSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkFriendshipStatus() async {
    final id = await SupabaseService.getActiveFriendshipId();
    if (mounted) {
      setState(() {
        _activeFriendshipId = id;
        _isLoading = false;
        if (id != null) {
          _listenForMessages(id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no active friendship, check for pending requests or show invite
    if (_activeFriendshipId == null) {
      return _buildNoFriendState();
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: [
          HomeDashboard(friendshipId: _activeFriendshipId),
          const CameraScreen(),
        ],
      ),
    );
  }

  Widget _buildNoFriendState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Welcome to Venma")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.getPendingRequests(),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Venma is for close friends.",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchUserScreen()),
                    ).then((_) => _checkFriendshipStatus());
                  },
                  child: const Text("Find a Friend"),
                ),
                const SizedBox(height: 40),
                if (requests.isNotEmpty) ...[
                  const Text("Pending Requests:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  ...requests.map((req) => _buildRequestCard(req)),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    return Card(
      color: AppColors.surface,
      child: ListTile(
        title: const Text("New Friend Request", style: TextStyle(color: Colors.white)),
        subtitle: Text("From User ID: ${req['user_id_1']}", style: const TextStyle(color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                try {
                  await SupabaseService.acceptRequest(req['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Request accepted!")),
                    );
                  }
                  _checkFriendshipStatus();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error accepting: $e")),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                try {
                  await SupabaseService.rejectRequest(req['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Request rejected")),
                    );
                  }
                  setState(() {}); // Refresh to remove card
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error rejecting: $e")),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final String? friendshipId;
  const HomeDashboard({super.key, this.friendshipId});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _friendProfile;
  List<Map<String, dynamic>> _myStatuses = [];
  int _streak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _listenForNudges();
  }

  Future<void> _fetchData() async {
    try {
      final userId = SupabaseService.currentUser!.id;
      _userProfile = await SupabaseService.getUserProfile(userId);
      
      if (widget.friendshipId != null) {
        _friendProfile = await SupabaseService.getFriendDetails(widget.friendshipId!);
        _streak = await SupabaseService.getStreak(widget.friendshipId!);
      }
      
      // Fetch my statuses
      final myStatuses = await SupabaseService.getFriendStatus(userId).first;
      if (mounted) setState(() => _myStatuses = myStatuses);
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenForNudges() {
    if (widget.friendshipId == null) return;
    SupabaseService.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('friendship_id', widget.friendshipId!)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((messages) async {
          if (messages.isNotEmpty) {
            final msg = messages.first;
            if (msg['type'] == 'nudge' && msg['sender_id'] != SupabaseService.currentUser!.id) {
              // Check if nudge is recent (e.g., within last 10 seconds) to avoid vibrating on old nudges
              final createdAt = DateTime.parse(msg['created_at']);
              if (DateTime.now().difference(createdAt).inSeconds < 10) {
                 // Vibrate
                 bool? hasVibrator = await Vibration.hasVibrator();
                 if (hasVibrator == true) {
                   Vibration.vibrate();
                 }
              }
            }
          }
        });
  }

  void _handleCall(bool isVideo) {
    if (_friendProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend profile not loaded yet. Please wait.")),
      );
      return;
    }
    final friendId = _friendProfile!['id'];
    if (friendId == null || friendId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot call: Friend ID is missing.")),
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

  void _postStatus() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen()));
  }

  void _viewMyStatus() {
    if (_myStatuses.isEmpty) {
      _postStatus();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewScreen(
          statuses: _myStatuses,
          userName: "Me",
          userAvatar: _userProfile?['avatar_url'] ?? "",
        ),
      ),
    ).then((_) => _fetchData()); // Refresh on return
  }

  void _viewFriendStatus() {
    if (_friendProfile == null) return;
    
    SupabaseService.getFriendStatus(_friendProfile!['id']).first.then((statuses) {
      if (statuses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No active statuses.")));
        }
        return;
      }
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewScreen(
              statuses: statuses,
              userName: _friendProfile!['display_name'] ?? "Friend",
              userAvatar: _friendProfile!['avatar_url'] ?? "https://i.pravatar.cc/150?img=33",
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context),
              const Spacer(),
              
              // Friend Status
              _buildFriendStatus(),
              const Spacer(),
              
              // Center Image
              _buildCenterImage(),
              const Spacer(),
              
              // Communication Actions
              _buildCommunicationActions(context),
              const SizedBox(height: 20),
              
              // Chat Preview
              if (widget.friendshipId != null)
                _buildChatPreview(context),
              const Spacer(),
              
              // Footer
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final avatarUrl = _userProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=11";
    final fluttermoji = _userProfile?['fluttermoji'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
          child: FlippingAvatar(
            imageUrl: avatarUrl,
            fluttermoji: fluttermoji,
            radius: 20,
            isLocalUser: true,
          ),
        ),
        IconButton(
          icon: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.primary),
          onPressed: () {},
        ),
        const Text(
          "Version 1",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFriendStatus() {
    final friendName = _friendProfile?['display_name'] ?? "Friend";
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            friendName, 
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: 10),
        StreamBuilder<Map<String, dynamic>>(
          stream: widget.friendshipId != null 
              ? SupabaseService.getFriendshipStream(widget.friendshipId!) 
              : null,
          builder: (context, snapshot) {
            final streak = snapshot.data?['streak_score'] ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
              ),
              child: Text(
                "$streak 🔥", 
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            );
          }
        ),
      ],
    ).animate().fadeIn().scale();
  }

  Widget _buildCenterImage() {
    final friendAvatar = _friendProfile?['avatar_url'] ?? "https://i.pravatar.cc/300?img=33";
    final friendFluttermoji = _friendProfile?['fluttermoji'];

    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 15,
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: FlippingAvatar(
        imageUrl: friendAvatar,
        fluttermoji: friendFluttermoji,
        radius: 125,
        isLocalUser: false,
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack)
      .shimmer(delay: 1500.ms, duration: 2500.ms, color: Theme.of(context).colorScheme.primary.withOpacity(0.3));
  }

  Widget _buildCommunicationActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.call, "Call", () => _handleCall(false)),
        _buildPinchButton(context),
        _buildActionButton(Icons.videocam, "Video", () => _handleCall(true)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  Widget _buildPinchButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (widget.friendshipId != null) {
          try {
             await SupabaseService.sendNudge(widget.friendshipId!);
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Nudge sent!")),
               );
             }
          } catch (e) {
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text("Error: $e")),
               );
             }
          }
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(Icons.back_hand, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text("Pinch", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
      .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1200.ms, curve: Curves.easeInOut);
  }

  Widget _buildChatPreview(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: SupabaseService.getLatestMessage(widget.friendshipId!),
      builder: (context, snapshot) {
        final msg = snapshot.data;
        final content = msg?['content'] ?? "No messages yet";
        final senderId = msg?['sender_id'];
        final isMe = senderId == SupabaseService.currentUser?.id;
        
        final bubbleColor = isMe ? Colors.blue : Colors.orange;
        final textColor = Colors.white;

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friendshipId: widget.friendshipId)));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: bubbleColor,
                      child: Icon(Icons.person, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: bubbleColor.withOpacity(0.2), // Light background
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: bubbleColor),
                        ),
                        child: Text(
                          content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Text(
                    "Besties 20", // Sticker
                    style: TextStyle(
                      fontFamily: 'Cursive',
                      fontSize: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final userAvatar = _userProfile?['avatar_url'] ?? "";
    final friendAvatar = _friendProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=33";
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: _viewMyStatus,
          onLongPress: _postStatus,
          child: _buildStoryCircle(
            imageUrl: userAvatar, 
            isUser: true, 
            hasStory: _myStatuses.isNotEmpty
          ),
        ),
        _buildFlashFuryButton(),
        GestureDetector(
          onTap: _viewFriendStatus,
          child: _buildStoryCircle(
            imageUrl: friendAvatar, 
            isUser: false,
            hasStory: true // We assume true for friend loop or could check, but simpler for now
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCircle({required String imageUrl, required bool isUser, required bool hasStory}) {
    Color borderColor = Colors.grey;
    if (hasStory) {
      borderColor = isUser ? Colors.blue : Colors.green;
    }
    
    if (imageUrl.isEmpty) {
      // Fallback for empty avatar URL
       return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[900],
        backgroundImage: CachedNetworkImageProvider(imageUrl),
        onBackgroundImageError: (_, __) {}, 
        child: null,
      ),
    );
  }

  Widget _buildFlashFuryButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatusListScreen(friendshipId: widget.friendshipId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Colors.orange, Colors.red]),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flash_on, color: Colors.orange),
        ),
      ),
    );
  }
}
