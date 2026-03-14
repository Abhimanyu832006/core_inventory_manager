class AppConstants {
  // ── Change this to your homelab IP when running on network ──
  static const String apiBaseUrl = 'https://api.coreinventory.shop';

  // ── Token storage key ──
  static const String tokenKey = 'ci_access_token';
  static const String userNameKey = 'ci_user_name';
  static const String userEmailKey = 'ci_user_email';
  static const String userRoleKey = 'ci_user_role';

  // ── Status colors (for badges) ──
  static const Map<String, int> statusColors = {
    'draft': 0xFF9E9E9E,
    'waiting': 0xFFFF9800,
    'ready': 0xFF2196F3,
    'done': 0xFF4CAF50,
    'cancelled': 0xFFF44336,
  };
}
