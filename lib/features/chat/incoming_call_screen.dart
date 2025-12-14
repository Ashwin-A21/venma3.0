import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Map<String, dynamic>? _callerProfile;

  @override
  void initState() {
    super.initState();
    _fetchCallerProfile();
  }

  Future<void> _fetchCallerProfile() async {
    final callerId = widget.call['caller_id'];
    final profile = await SupabaseService.getUserProfile(callerId);
    if (mounted) {
      setState(() {
        _callerProfile = profile;
      });
    }
  }

  Future<void> _acceptCall() async {
    await SupabaseService.updateCallStatus(widget.call['id'], 'answering');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            friendName: _callerProfile?['display_name'] ?? "Unknown",
            friendAvatar: _callerProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=11",
            isVideo: widget.call['is_video'] ?? false,
            callId: widget.call['id'],
            isIncoming: true,
          ),
        ),
      );
    }
  }

  Future<void> _rejectCall() async {
    await SupabaseService.updateCallStatus(widget.call['id'], 'rejected');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callerName = _callerProfile?['display_name'] ?? "Unknown";
    final callerAvatar = _callerProfile?['avatar_url'] ?? "https://i.pravatar.cc/150?img=11";
    final isVideo = widget.call['is_video'] ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            callerAvatar,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.8),
            colorBlendMode: BlendMode.darken,
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Text(
                  isVideo ? "Incoming Video Call..." : "Incoming Voice Call...",
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 20),
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                CircleAvatar(
                  radius: 80,
                  backgroundImage: NetworkImage(callerAvatar),
                ).animate(onPlay: (c) => c.repeat()).shake(duration: 1000.ms),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.call_end, Colors.white, Colors.red, _rejectCall, "Decline"),
                      _buildActionButton(Icons.call, Colors.white, Colors.green, _acceptCall, "Accept"),
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

  Widget _buildActionButton(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap, String label) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
