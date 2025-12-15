import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';

class FlippingAvatar extends StatefulWidget {
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
  State<FlippingAvatar> createState() => _FlippingAvatarState();
}

class _FlippingAvatarState extends State<FlippingAvatar> {
  bool _showRealImage = true;
  Timer? _timer;
  bool _imageLoadError = false;

  @override
  void initState() {
    super.initState();
    if (widget.fluttermoji != null && widget.fluttermoji!.isNotEmpty) {
      _startFlipping();
    }
  }

  @override
  void didUpdateWidget(covariant FlippingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset image error state when URL changes
    if (widget.imageUrl != oldWidget.imageUrl) {
      setState(() => _imageLoadError = false);
    }
    
    if (widget.fluttermoji != oldWidget.fluttermoji) {
      if (widget.fluttermoji != null && widget.fluttermoji!.isNotEmpty) {
        _startFlipping();
      } else {
        _timer?.cancel();
        setState(() => _showRealImage = true);
      }
    }
  }

  void _startFlipping() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _showRealImage = !_showRealImage;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _hasValidImageUrl {
    return widget.imageUrl.isNotEmpty && 
           widget.imageUrl.startsWith('http') &&
           !_imageLoadError;
  }

  bool get _hasValidFluttermoji {
    return widget.fluttermoji != null && widget.fluttermoji!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // If no fluttermoji, always show real image
    if (!_hasValidFluttermoji) {
      return _buildRealImageAvatar();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotateAnim,
          child: child,
          builder: (context, child) {
            final isUnder = (ValueKey(_showRealImage) != child!.key);
            var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
            tilt *= isUnder ? -1.0 : 1.0;
            final value = isUnder ? 3.14 - rotateAnim.value : rotateAnim.value;
            
            return Transform(
              transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
              alignment: Alignment.center,
              child: child,
            );
          },
        );
      },
      child: _showRealImage
          ? _buildRealImageAvatar(key: const ValueKey(1))
          : _buildFluttermojiAvatar(key: const ValueKey(2)),
    );
  }

  Widget _buildRealImageAvatar({Key? key}) {
    return Container(
      key: key,
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: ClipOval(
        child: _hasValidImageUrl
            ? Image.network(
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
                  debugPrint("Avatar Load Error: $error");
                  // Mark as error after first failure
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_imageLoadError) {
                      setState(() => _imageLoadError = true);
                    }
                  });
                  return _buildFallbackIcon();
                },
              )
            : _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFluttermojiAvatar({Key? key}) {
    return Container(
      key: key,
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: ClipOval(
        child: widget.isLocalUser
            ? FluttermojiCircleAvatar(
                radius: widget.radius,
                backgroundColor: AppColors.surface,
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
      debugPrint("SVG Parse Error: $e");
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
