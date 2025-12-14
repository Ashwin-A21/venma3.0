import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import 'friend_selection_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Select Version",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn().slideX(),
              const SizedBox(height: 10),
              Text(
                "Choose your Venma experience",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ).animate().fadeIn().slideX(delay: 100.ms),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  children: [
                    _buildVersionTile(
                      context,
                      version: "Version 1",
                      title: "The Inner Circle",
                      isActive: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendSelectionScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn().slideY(delay: 200.ms),
                    const SizedBox(height: 16),
                    _buildVersionTile(
                      context,
                      version: "Version 2",
                      title: "Exclusive",
                      isActive: false,
                    ).animate().fadeIn().slideY(delay: 300.ms),
                    const SizedBox(height: 16),
                    _buildVersionTile(
                      context,
                      version: "Version 3",
                      title: "Comrades",
                      isActive: false,
                    ).animate().fadeIn().slideY(delay: 400.ms),
                    const SizedBox(height: 16),
                    _buildVersionTile(
                      context,
                      version: "Version 4",
                      title: "Squad",
                      isActive: false,
                    ).animate().fadeIn().slideY(delay: 500.ms),
                    const SizedBox(height: 16),
                    _buildVersionTile(
                      context,
                      version: "Version 5",
                      title: "Community",
                      isActive: false,
                    ).animate().fadeIn().slideY(delay: 600.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionTile(
    BuildContext context, {
    required String version,
    required String title,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  version.split(' ')[1],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    version,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Coming Soon",
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            if (isActive)
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
