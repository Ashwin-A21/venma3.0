import 'package:flutter/material.dart';
import '../../core/extensions/color_extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = SupabaseService.currentUser!.id;
      final profile = await SupabaseService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      setState(() => _isLoading = true);
      try {
        final userId = SupabaseService.currentUser!.id;
        final ext = file.path.split('.').last;
        final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        // Upload
        final url = await SupabaseService.uploadFile(File(file.path), 'avatars', path);
        
        // Update Profile
        await SupabaseService.updateProfile({'avatar_url': url});
        
        // Clear the image cache to ensure new image loads
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        
        // Refresh profile
        await _fetchProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating avatar: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStaticAvatar(String? avatarUrl, String? fluttermoji, double radius) {
    // Build static avatar - shows DP if available, otherwise fluttermoji, otherwise fallback icon
    // This does NOT flip - it's a static display
    
    final hasValidUrl = avatarUrl != null && 
                        avatarUrl.isNotEmpty && 
                        avatarUrl.startsWith('http');
    
    final hasValidFluttermoji = fluttermoji != null && fluttermoji.isNotEmpty;
    
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: Border.all(color: AppColors.primary.withOpacityValue(0.3), width: 2),
      ),
      child: ClipOval(
        child: hasValidUrl
            ? Image.network(
                '$avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}', // Cache busting
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to fluttermoji or icon
                  if (hasValidFluttermoji) {
                    return _buildMojiAvatar(fluttermoji, radius);
                  }
                  return _buildFallbackIcon(radius);
                },
              )
            : hasValidFluttermoji
                ? _buildMojiAvatar(fluttermoji, radius)
                : _buildFallbackIcon(radius),
      ),
    );
  }

  Widget _buildMojiAvatar(String? fluttermoji, double radius) {
    if (fluttermoji == null || fluttermoji.isEmpty) {
      return _buildFallbackIcon(radius);
    }
    try {
      return SvgPicture.string(
        fluttermoji,
        fit: BoxFit.cover,
        height: radius * 2,
        width: radius * 2,
        placeholderBuilder: (context) => _buildFallbackIcon(radius),
      );
    } catch (e) {
      return _buildFallbackIcon(radius);
    }
  }

  Widget _buildFallbackIcon(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final avatarUrl = _profile?['avatar_url'];
    final fluttermoji = _profile?['fluttermoji'];
    final displayName = _profile?['display_name'] ?? "User";
    final username = _profile?['username'] ?? "username";
    final balance = _profile?['atman_balance'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("My Profile"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Picture - STATIC (no flipping)
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Center(
                child: Stack(
                  children: [
                    _buildStaticAvatar(avatarUrl, fluttermoji, 60),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().scale(),
            const SizedBox(height: 16),
            
            // Name and Handle
            Text(
              displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "@$username",
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 30),
            
            // Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton(context, Icons.alternate_email, "Contact Info", () {
                  final email = SupabaseService.currentUser?.email ?? "No Email";
                  final phone = _profile?['phone'] ?? "Unspecified";
                  _showContactPopup(context, email, phone);
                }),
                _buildTabButton(context, Icons.fingerprint, "Venma ID", () {
                  _showPopup(context, "Venma ID", "ID: ${_profile?['id'] ?? 'Unknown'}");
                }),
                _buildTabButton(context, Icons.hourglass_empty, "Venma Age", () {
                   final createdAt = DateTime.parse(_profile?['created_at'] ?? DateTime.now().toIso8601String());
                   final duration = DateTime.now().difference(createdAt);
                   final days = duration.inDays;
                   _showPopup(context, "Venma Age", "$days days");
                }),
                _buildTabButton(context, Icons.more_horiz, "Settings", () {
                   // Menu
                }),
              ],
            ).animate().slideY(begin: 0.5, end: 0),
            
            const SizedBox(height: 40),
            
            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.primary.withOpacityValue(0.3)),
              ),
              child: Text(
                "$balance atman",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 20),
            
            // Edit Mymoji
            ElevatedButton.icon(
              onPressed: () {
                _showAvatarEditor(context);
              },
              icon: const Icon(Icons.face),
              label: const Text("Edit Mymoji"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  "Customize Your Avatar", 
                  style: TextStyle(
                    color: AppColors.textPrimary, 
                    fontSize: 20, 
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 16),
                // Preview of the current Fluttermoji
                SizedBox(
                  height: 100,
                  child: FluttermojiCircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.background,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FluttermojiCustomizer(
                    scaffoldWidth: MediaQuery.of(context).size.width,
                    autosave: true, // Auto-save to SharedPreferences so we can encode it later
                    theme: FluttermojiThemeData(
                      boxDecoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      primaryBgColor: AppColors.background,
                      secondaryBgColor: AppColors.surface,
                      labelTextStyle: TextStyle(color: AppColors.textPrimary),
                      iconColor: AppColors.textSecondary,
                      selectedIconColor: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        // Get the SVG from shared preferences via FluttermojiFunctions
                        final svgValue = await FluttermojiFunctions().encodeMySVGtoString();
                        
                        if (svgValue == null || svgValue.isEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to encode avatar. Please try customizing first.")),
                            );
                          }
                          return;
                        }
                        
                        // Save to Supabase
                        await SupabaseService.updateProfile({'fluttermoji': svgValue});
                        
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Avatar saved!")),
                          );
                          // Refresh the profile to show the new avatar
                          _fetchProfile();
                        }
                      } catch (e) {
                        debugPrint("Error saving avatar: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error saving avatar: $e")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Save Avatar"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacityValue(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          // Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showContactPopup(BuildContext context, String email, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Contact Info", style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: $email", style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text("Mobile: $phone", style: const TextStyle(color: AppColors.textSecondary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditPhoneDialog(context, phone == "Unspecified" ? "" : phone);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(BuildContext context, String currentPhone) {
    final controller = TextEditingController(text: currentPhone);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Update Mobile", style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: "Enter mobile number",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await SupabaseService.updateProfile({'phone': controller.text});
              if (mounted) {
                Navigator.pop(context);
                _fetchProfile();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showPopup(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(content, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
