import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const String _appLockPrefKey = 'expense_os_app_lock_enabled';

  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if hardware supports biometrics (Fingerprint, Face ID, or Device PIN)
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  static bool isAuthenticating = false;

  /// Prompt native biometric authentication dialog
  Future<bool> authenticate({String reason = 'Authenticate to access Expense OS Command Center'}) async {
    if (isAuthenticating) return false;
    isAuthenticating = true;
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        // If device has no hardware biometrics enabled in emulator/device, return true for demo access
        return true;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: false, // Must be false on iOS to prevent infinite evaluation loops
          biometricOnly: false, // Allows device PIN/Passcode fallback if Face ID fails
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      isAuthenticating = false;
    }
  }

  /// Read App Lock setting state from SharedPreferences
  Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_appLockPrefKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Save App Lock setting state to SharedPreferences
  Future<void> setAppLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appLockPrefKey, enabled);
    } catch (e) {
      debugPrint('Error saving App Lock preference: $e');
    }
  }
}
