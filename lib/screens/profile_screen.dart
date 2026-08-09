import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final BiometricService _biometricService = BiometricService();
  String _selectedCurrency = '₹ INR';
  bool _isAppLockEnabled = false;
  String? _customAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
    _loadCustomAvatar();
  }

  Future<void> _loadCustomAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customAvatarPath = prefs.getString('custom_avatar_path');
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
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
        }
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _updateProfilePhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Profile Photo',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select an option to update your picture:',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option 1: Take Live Photo (Camera)
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: AppTheme.accentCyan, size: 24),
              ),
              title: Text('Take Live Photo (Camera)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Capture a new photo with device camera', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
            const Divider(color: Colors.white12, height: 16),

            // Option 2: Upload Photo from Gallery
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library, color: AppTheme.accentGreen, size: 24),
              ),
              title: Text('Upload Photo from Gallery', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Choose an existing photo from device storage', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAppLockState() async {
    final enabled = await _biometricService.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _isAppLockEnabled = enabled;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // Prompt biometric authentication before enabling App Lock
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable Biometric App Lock',
      );
      if (authenticated) {
        await _biometricService.setAppLockEnabled(true);
        if (mounted) {
          setState(() {
            _isAppLockEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric App Lock Enabled', style: GoogleFonts.poppins()),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric authentication failed', style: GoogleFonts.poppins()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      }
    } else {
      // Disabling App Lock
      await _biometricService.setAppLockEnabled(false);
      if (mounted) {
        setState(() {
          _isAppLockEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric App Lock Disabled', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.amber,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text('Sign Out', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out of Expense OS?', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: Text('Sign Out', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabaseService.signOut();
      widget.onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabaseService.currentUser;
    final userEmail = user?.email ?? 'Guest User (Demo Mode)';
    final String initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'G';

    ImageProvider? avatarImage;
    if (_customAvatarPath != null && _customAvatarPath!.isNotEmpty) {
      if (kIsWeb || _customAvatarPath!.startsWith('http')) {
        avatarImage = NetworkImage(_customAvatarPath!);
      } else {
        avatarImage = FileImage(File(_customAvatarPath!));
      }
    } else if (user?.userMetadata?['avatar_url'] != null) {
      avatarImage = NetworkImage(user!.userMetadata!['avatar_url']);
    } else if (user?.userMetadata?['picture'] != null) {
      avatarImage = NetworkImage(user!.userMetadata!['picture']);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User Avatar Card
              GlassCard(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _updateProfilePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.accentCyan.withOpacity(0.2),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(
                                    initial,
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.accentCyan,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.accentCyan,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userEmail,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user != null ? 'Supabase Connected' : 'Local Demo Mode',
                                style: GoogleFonts.poppins(color: AppTheme.accentGreen, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Options
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.currency_rupee, color: AppTheme.accentCyan),
                      title: Text('Primary Currency', style: GoogleFonts.poppins(color: Colors.white)),
                      trailing: DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color(0xFF0F172A),
                        style: GoogleFonts.poppins(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: ['\$ USD', '₹ INR', '€ EUR', '£ GBP'].map((curr) {
                          return DropdownMenuItem(value: curr, child: Text(curr));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                    const Divider(color: Colors.white10),

                    ListTile(
                      leading: const Icon(Icons.cloud_done_outlined, color: AppTheme.accentCyan),
                      title: Text('Supabase Cloud Sync', style: GoogleFonts.poppins(color: Colors.white)),
                      subtitle: Text('Automated real-time cloud backup', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.check_circle, color: AppTheme.accentGreen),
                    ),
                    const Divider(color: Colors.white10),

                    SwitchListTile(
                      activeThumbColor: AppTheme.accentCyan,
                      secondary: const Icon(Icons.security, color: AppTheme.accentCyan),
                      title: Text('Security & Biometrics', style: GoogleFonts.poppins(color: Colors.white)),
                      subtitle: Text(
                        _isAppLockEnabled ? 'Fingerprint / Face ID lock active' : 'Tap to enable biometric app lock',
                        style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _isAppLockEnabled,
                      onChanged: _toggleAppLock,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text('SIGN OUT', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.accentRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
