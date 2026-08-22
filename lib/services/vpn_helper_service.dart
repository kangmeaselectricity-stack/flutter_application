import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VpnHelperService {
  static const _channel = MethodChannel('com.kangmeas.vpn_helper');

  static const _keyServer = 'vpn_server';
  static const _keyPsk = 'vpn_psk';
  static const _keyUsername = 'vpn_username';
  static const _keyPassword = 'vpn_password';

  // ========================
  //  🔐 Credentials (Save/Load)
  // ========================

  Future<void> saveConfig({
    required String server,
    required String psk,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServer, server.trim());
    await prefs.setString(_keyPsk, psk.trim());
    await prefs.setString(_keyUsername, username.trim());
    await prefs.setString(_keyPassword, password.trim());
    debugPrint('🔑 [VPN Config] Saved successfully');
  }

  Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'server': prefs.getString(_keyServer) ?? '',
      'psk': prefs.getString(_keyPsk) ?? '',
      'username': prefs.getString(_keyUsername) ?? '',
      'password': prefs.getString(_keyPassword) ?? '',
    };
  }

  // ========================
  //  📱 Open VPN Settings
  // ========================

  /// បើក VPN Settings លើ Android (ដោយ Method Channel)
  /// ត្រឡប់ true បើជោគជ័យ
  Future<bool> openVpnSettings() async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('ℹ️ [VPN] Not Android — skipping system settings open');
        return false;
      }
      final result = await _channel.invokeMethod<bool>('openVpnSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ [VPN Settings Error] $e');
      return false;
    }
  }

  // ========================
  //  📡 VPN Status Detection
  // ========================

  /// ពិនិត្យ VPN Interface ដោយ Native Channel
  Future<bool> isVpnActiveNative() async {
    try {
      if (!Platform.isAndroid) return false;
      final result = await _channel.invokeMethod<bool>('isVpnActive');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ [VPN Status Native Error] $e');
      return false;
    }
  }

  /// ពិនិត្យ VPN ដោយ Ping NAS IP (10 second timeout)
  /// ● ប្រសិនបើ NAS IP ទំនាក់ទំនងបាន = VPN Connected
  /// ● ប្រសិនបើ timeout = Disconnected
  Future<bool> isNasReachable(String nasIp) async {
    if (nasIp.isEmpty) return false;
    try {
      // ​ជ្រើស port 5000 (DSM) ឬ 5005 (WebDAV)
      final socket = await Socket.connect(
        nasIp,
        5000,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      debugPrint('✅ [VPN Ping] NAS $nasIp reachable — VPN is connected!');
      return true;
    } catch (_) {
      debugPrint('❌ [VPN Ping] NAS $nasIp NOT reachable — VPN disconnected');
      return false;
    }
  }

  /// ពិនិត្យ VPN Status ពេញលេញ (Native + Ping)
  Future<Map<String, dynamic>> checkVpnStatus(String nasIp) async {
    final nativeActive = await isVpnActiveNative();
    final nasReachable = await isNasReachable(nasIp);
    return {
      'vpnInterface': nativeActive,
      'nasReachable': nasReachable,
      'isConnected': nativeActive || nasReachable,
    };
  }
}
