import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class UserProfileModal extends StatefulWidget {
  final VoidCallback? onSignOut;
  const UserProfileModal({super.key, this.onSignOut});

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  final SupabaseService _supabaseService = SupabaseService();

  String _displayName = 'User';
  String _email = 'user@gmail.com';
  String? _avatarUrl;
  String? _customAvatarPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _supabaseService.currentUser;

    final googleEmail = prefs.getString('google_user_email');
    final googleAvatar = prefs.getString('google_user_avatar');
    final customName = prefs.getString('custom_user_name');
    final customAvatar = prefs.getString('custom_avatar_path');

    String email = user?.email ?? googleEmail ?? 'Member';
    String name = customName ??
        (user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            (email.contains('@') ? email.split('@').first : 'Expense User'));
    String? photoUrl = googleAvatar ?? user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture'];

    if (mounted) {
      setState(() {
        _displayName = name;
        _email = email;
        _avatarUrl = photoUrl;
        _customAvatarPath = customAvatar;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_avatar_path', pickedFile.path);

        if (mounted) {
          setState(() {
            _customAvatarPath = pickedFile.path;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile photo updated!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not set profile photo: $e', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile Name', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.monexBlue, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.monexBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_user_name', newName);
      if (mounted) {
        setState(() => _displayName = newName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile name updated!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Widget _buildAvatarWidget() {
    if (_customAvatarPath != null && File(_customAvatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: FileImage(File(_customAvatarPath!)),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: NetworkImage(_avatarUrl!),
      );
    } else {
      return CircleAvatar(
        radius: 44,
        backgroundColor: AppTheme.monexBlue,
        child: Text(
          _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
          style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: AppTheme.monexBlue)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAECF0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Profile Avatar Hero
                  GestureDetector(
                    onTap: _pickAvatarImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.monexBlue, width: 2.5),
                          ),
                          child: _buildAvatarWidget(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.monexBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xFF131A29) : Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Display Name & Email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _editDisplayName,
                        child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.monexBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Badge: "PRO Member • Cloud Synced ☁️"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFB2DDFF), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PRO Member • Cloud Synced ☁️',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.monexBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal Information Section Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Full Name',
                          value: _displayName,
                          onTap: _editDisplayName,
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        _buildInfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          value: _email,
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        _buildInfoTile(
                          icon: Icons.verified_user_outlined,
                          label: 'Account Status',
                          value: 'Active & Verified',
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        _buildInfoTile(
                          icon: Icons.calendar_today_rounded,
                          label: 'Member Since',
                          value: 'August 2026',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF331414) : const Color(0xFFFEF3F2),
                        foregroundColor: AppTheme.expenseRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? const Color(0xFF5C2222) : const Color(0xFFFECDCA), width: 1.2),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _supabaseService.signOut();
                        if (widget.onSignOut != null) {
                          widget.onSignOut!();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.expenseRed, size: 20),
                      label: Text(
                        'Sign Out of Expense OS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.expenseRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isDark = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.monexBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppTheme.monexBlue),
      ),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
          : null,
    );
  }
}
