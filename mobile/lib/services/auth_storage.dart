import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored authentication session payload
class StoredSessionData {
  final String token;
  final String userId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const StoredSessionData({
    required this.token,
    required this.userId,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'token': token,
        'user_id': userId,
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  factory StoredSessionData.fromJson(Map<String, dynamic> json) {
    return StoredSessionData(
      token: (json['token'] ?? '').toString(),
      userId: (json['user_id'] ?? 'executive_user').toString(),
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString()) ??
              DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
    );
  }
}

/// Low-Level Storage Layer for Persistent Session Tokens
///
/// Hides platform-specific details. On Flutter Web, SharedPreferences
/// persists to window.localStorage. On mobile, persists to secure shared prefs.
class AuthStorage {
  static final AuthStorage instance = AuthStorage._internal();
  AuthStorage._internal();

  static const String _sessionKey = 'ziva_auth_persistent_session_v1';

  /// Saves session data to persistent storage
  Future<bool> saveSession(StoredSessionData session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(session.toJson());
      return await prefs.setString(_sessionKey, jsonString);
    } catch (e) {
      debugPrint('[AuthStorage] Error saving session: $e');
      return false;
    }
  }

  /// Retrieves stored session data or null if not found or corrupted
  Future<StoredSessionData?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final session = StoredSessionData.fromJson(decoded);

      if (session.isExpired) {
        debugPrint('[AuthStorage] Session expired on ${session.expiresAt}. Purging.');
        await clearSession();
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('[AuthStorage] Error retrieving session (failing closed): $e');
      await clearSession();
      return null;
    }
  }

  /// Clears stored session data from persistent storage
  Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('[AuthStorage] Error clearing session: $e');
      return false;
    }
  }
}
