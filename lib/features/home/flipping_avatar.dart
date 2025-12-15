import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';

/// A simple avatar widget that shows the user's profile picture or fluttermoji
/// No flipping animation - just displays the avatar as set
class ProfileAvatar extends StatefulWidget {
  final String imageUrl;
  final String? fluttermoji;
  final double radius;
  final bool isLocalUser;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.fluttermoji,
    this.radius = 20,
    this.isLocalUser = false,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageLoadError = false;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      setState(() => _imageLoadError = false);
    }
  }

  bool get _hasValidImageUrl {
    return widget.imageUrl.isNotEmpty && 
           widget.imageUrl.startsWith('http') &&
           !_imageLoadError;
  }

  @override
  Widget build(BuildContext context) {
    // If we have a valid image URL, show the image
    if (_hasValidImageUrl) {
      return _buildImageAvatar();
    }
    
    // Otherwise fallback to fluttermoji or default icon
    if (widget.fluttermoji != null && widget.fluttermoji!.isNotEmpty) {
      return _buildFluttermojiAvatar();
    }
    
    return _buildFallbackIcon();
  }

  Widget _buildImageAvatar() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          width: widget.radius * 2,
          height: widget.radius * 2,
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageLoadError) {
                setState(() => _imageLoadError = true);
              }
            });
            return _buildFallbackIcon();
          },
        ),
      ),
    );
  }

  Widget _buildFluttermojiAvatar() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: widget.isLocalUser
            ? FluttermojiCircleAvatar(
                radius: widget.radius,
                backgroundColor: Theme.of(context).cardColor,
              )
            : _buildSvgFluttermoji(),
      ),
    );
  }

  Widget _buildSvgFluttermoji() {
    try {
      return SvgPicture.string(
        widget.fluttermoji ?? "",
        fit: BoxFit.cover,
        height: widget.radius * 2,
        width: widget.radius * 2,
        placeholderBuilder: (context) => _buildFallbackIcon(),
      );
    } catch (e) {
      return _buildFallbackIcon();
    }
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Icon(
        Icons.person,
        size: widget.radius,
        color: Colors.grey[600],
      ),
    );
  }
}

/// Legacy FlippingAvatar - kept for compatibility but now just wraps ProfileAvatar
class FlippingAvatar extends StatelessWidget {
  final String imageUrl;
  final String? fluttermoji;
  final double radius;
  final bool isLocalUser;

  const FlippingAvatar({
    super.key,
    required this.imageUrl,
    this.fluttermoji,
    this.radius = 20,
    this.isLocalUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      imageUrl: imageUrl,
      fluttermoji: fluttermoji,
      radius: radius,
      isLocalUser: isLocalUser,
    );
  }
}
