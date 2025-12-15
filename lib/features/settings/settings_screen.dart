import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/extensions/color_extensions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          _buildSectionHeader(context, "Appearance"),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context: context,
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            iconColor: isDark ? Colors.indigo : Colors.orange,
            title: "Theme",
            subtitle: isDark ? "Dark Mode" : "Light Mode",
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeTrackColor: AppColors.primary.withOpacityValue(0.5),
              activeThumbColor: AppColors.primary,
            ),
            onTap: () => themeProvider.toggleTheme(),
          ),
          
          const SizedBox(height: 24),
          
          // Account Section
          _buildSectionHeader(context, "Account"),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context: context,
            icon: Icons.person_outline,
            iconColor: AppColors.primary,
            title: "Profile",
            subtitle: "View and edit your profile",
            onTap: () {
              Navigator.pop(context);
              // Already on profile or navigate there
            },
          ),
          
          const SizedBox(height: 24),
          
          // Danger Zone
          _buildSectionHeader(context, "Account Actions"),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context: context,
            icon: Icons.logout,
            iconColor: Colors.red,
            title: "Sign Out",
            subtitle: "Log out of your account",
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Sign Out"),
                  content: const Text("Are you sure you want to sign out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("Sign Out"),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && context.mounted) {
                await SupabaseService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacityValue(0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacityValue(0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacityValue(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right,
          color: Theme.of(context).iconTheme.color?.withOpacityValue(0.5),
        ),
        onTap: onTap,
      ),
    );
  }
}
