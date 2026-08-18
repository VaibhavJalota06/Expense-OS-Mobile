import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'supabase_service.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isUpdateAvailable;
  final bool isMandatory;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isUpdateAvailable,
    this.isMandatory = false,
  });
}

class AppUpdateService {
  static const String currentAppVersion = "3.0.3";
  static const int currentBuildNumber = 54;

  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Check if a newer version is published in Supabase or GitHub Releases
  Future<AppUpdateInfo> checkForUpdate() async {
    // 1. Check Supabase first if available
    try {
      final client = SupabaseService().safeClient;
      if (client != null) {
        final response = await client
            .from('app_updates')
            .select()
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          final latestVersion = (response['version'] as String? ?? currentAppVersion).replaceAll('v', '').trim();
          final downloadUrl = response['apk_url'] as String? ?? 'https://github.com/VaibhavJalota06/Expense-OS-Mobile/releases';
          final notes = response['changelog'] as String? ?? 'Performance improvements and new tools.';
          final mandatory = response['is_mandatory'] as bool? ?? false;

          final hasUpdate = _isNewer(latestVersion, currentAppVersion);
          if (hasUpdate) {
            return AppUpdateInfo(
              currentVersion: currentAppVersion,
              latestVersion: latestVersion,
              downloadUrl: downloadUrl,
              releaseNotes: notes,
              isUpdateAvailable: true,
              isMandatory: mandatory,
            );
          }
        }
      }
    } catch (_) {
      // Fallback to GitHub API
    }

    // 2. Check GitHub Releases API directly
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile/releases/latest'),
      );
      request.headers.set('User-Agent', 'ExpenseOS-MobileApp');
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tagName = (json['tag_name'] as String? ?? '').replaceAll('v', '').trim();
        final releaseNotes = json['body'] as String? ?? 'Exciting new improvements and bug fixes.';
        final htmlUrl = json['html_url'] as String? ?? 'https://github.com/VaibhavJalota06/Expense-OS-Mobile/releases';

        // Find direct apk asset url if available
        String downloadUrl = htmlUrl;
        final assets = json['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] as String? ?? htmlUrl;
              break;
            }
          }
        }

        final hasUpdate = _isNewer(tagName, currentAppVersion);
        return AppUpdateInfo(
          currentVersion: currentAppVersion,
          latestVersion: tagName.isNotEmpty ? tagName : currentAppVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : 'New release with latest features and optimizations.',
          isUpdateAvailable: hasUpdate,
          isMandatory: false,
        );
      }
    } catch (_) {}

    return AppUpdateInfo(
      currentVersion: currentAppVersion,
      latestVersion: currentAppVersion,
      downloadUrl: 'https://github.com/VaibhavJalota06/Expense-OS-Mobile/releases',
      releaseNotes: 'You are on the latest version of Expense OS.',
      isUpdateAvailable: false,
    );
  }

  bool _isNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Show the Update Dialog / Sheet to the user
  void showUpdateModal(BuildContext context, AppUpdateInfo info, {bool showUpToDateNotice = false}) {
    if (!info.isUpdateAvailable) {
      if (showUpToDateNotice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 You are on the latest version (v$currentAppVersion)',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
      return;
    }

    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      isDismissible: !info.isMandatory,
      enableDrag: !info.isMandatory,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A29) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.monexBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppTheme.monexBlue, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Update Available',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Version ${info.latestVersion} is ready to install',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1322) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAECF0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New:",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info.releaseNotes,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475467),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(info.downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.monexBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'DOWNLOAD & INSTALL UPDATE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
