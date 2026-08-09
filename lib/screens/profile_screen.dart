import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _customAvatarUrl;

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
        _customAvatarUrl = prefs.getString('custom_avatar_url');
      });
    }
  }

  Future<void> _updateProfilePhoto() async {
    final controller = TextEditingController(text: _customAvatarUrl ?? '');
    final newUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Profile Photo', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Enter an image URL or choose a preset avatar:', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://example.com/photo.jpg',
                hintStyle: GoogleFonts.poppins(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                prefixIcon: const Icon(Icons.link, color: AppTheme.accentCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Preset Avatar:', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
              ].map((url) => GestureDetector(
                onTap: () => Navigator.pop(context, url),
                child: CircleAvatar(radius: 26, backgroundImage: NetworkImage(url)),
              )).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save Profile Photo', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (newUrl != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_avatar_url', newUrl);
      if (mounted) {
        setState(() {
          _customAvatarUrl = newUrl;
        });
      }
    }
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
    final String? activeAvatar = (_customAvatarUrl != null && _customAvatarUrl!.isNotEmpty)
        ? _customAvatarUrl
        : (user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture']);
    final String initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'G';

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
                            backgroundImage: activeAvatar != null && activeAvatar.isNotEmpty
                                ? NetworkImage(activeAvatar)
                                : null,
                            child: (activeAvatar == null || activeAvatar.isEmpty)
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
