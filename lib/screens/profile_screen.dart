import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedCurrency = '\$ USD';

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
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.accentCyan.withOpacity(0.2),
                      child: const Icon(Icons.person, color: AppTheme.accentCyan, size: 32),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      leading: const Icon(Icons.attach_money, color: AppTheme.accentCyan),
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

                    ListTile(
                      leading: const Icon(Icons.security, color: AppTheme.accentCyan),
                      title: Text('Security & Biometrics', style: GoogleFonts.poppins(color: Colors.white)),
                      subtitle: Text('App lock protection enabled', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.lock_outline, color: Colors.white54),
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
                    padding: const EdgeInsets.vertical(14),
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
