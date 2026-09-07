import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'auth_storage.dart';

/// Authentication Session Management Module
///
/// Manages persistent sessions across browser page reloads without
/// prompting the user for passwords on every refresh, while maintaining
/// strict security boundaries and failing closed on errors.
class AuthSession {
  static final AuthSession instance = AuthSession._internal();
  AuthSession._internal();

  static const Duration _defaultTtl = Duration(days: 7);
  final Uuid _uuid = const Uuid();

  StoredSessionData? _activeSession;

  /// Returns currently loaded active session in memory (if valid)
  StoredSessionData? get activeSession => _activeSession;

  /// Checks whether an active unexpired session is loaded
  bool get isAuthenticated => _activeSession != null && !_activeSession!.isExpired;

  /// Creates a persistent session following successful password/PIN authentication
  Future<StoredSessionData?> createPersistentSession({
    String userId = 'executive_user',
    Duration ttl = _defaultTtl,
  }) async {
    try {
      final token = 'ziva_sec_${_uuid.v4().replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}';
      final issuedAt = DateTime.now();
      final expiresAt = issuedAt.add(ttl);

      final session = StoredSessionData(
        token: token,
        userId: userId,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );

      final saved = await AuthStorage.instance.saveSession(session);
      if (saved) {
        _activeSession = session;
        debugPrint('[AuthSession] Persistent session created for $userId (Expires: $expiresAt)');
        return session;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthSession] Error creating session: $e');
      return null;
    }
  }

  /// Retrieves current session from persistent storage
  Future<StoredSessionData?> getCurrentSessionFromStorage() async {
    final session = await AuthStorage.instance.getSession();
    _activeSession = session;
    return session;
  }

  /// App bootstrap helper: Attempts to restore an existing authenticated session
  /// Returns true if a valid, unexpired session was successfully restored.
  Future<bool> restoreSessionIfPossible() async {
    try {
      final session = await AuthStorage.instance.getSession();
      if (session != null && !session.isExpired) {
        _activeSession = session;
        debugPrint('[AuthSession] Silent re-authentication successful for ${session.userId}.');
        return true;
      } else {
        _activeSession = null;
        return false;
      }
    } catch (e) {
      debugPrint('[AuthSession] Silent re-authentication check failed closed: $e');
      _activeSession = null;
      return false;
    }
  }

  /// Clears persistent session on user logout or session revocation
  Future<void> clearPersistentSession() async {
    _activeSession = null;
    await AuthStorage.instance.clearSession();
    debugPrint('[AuthSession] Persistent session revoked and cleared.');
  }
}
