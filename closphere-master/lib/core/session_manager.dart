// lib/core/session_manager.dart

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  String? userId; // Supabase Auth UUID
  String? name;
  String? email;
  bool isGhalaAdmin = false;

  bool get isLoggedIn => userId != null && userId!.isNotEmpty;

  void saveSession(Map<String, dynamic> userMap) {
    userId = userMap['id']?.toString();
    name = userMap['name']?.toString();
    email = userMap['email']?.toString();
    isGhalaAdmin = userMap['isGhalaAdmin'] == true || userMap['role']?.toString().toLowerCase() == 'admin';
  }

  void clearSession() {
    userId = null;
    name = null;
    email = null;
    isGhalaAdmin = false;
  }

  void destroyActiveSession() {
    clearSession();
  }
}
