class AppConstants {
  // App Info
  static const String appName = 'PeerLink';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String signalingCollection = 'signaling';
  static const String friendRequestsCollection = 'friend_requests';
  static const String friendsSubcollection = 'friends';
  static const String blockedSubcollection = 'blocked';
  
  // Hive Boxes
  static const String messagesBox = 'messages';
  static const String sessionsBox = 'sessions';
  static const String usersBox = 'users';
  static const String requestsBox = 'requests';
  static const String settingsBox = 'settings';
  
  // Settings Keys
  static const String encryptionKeyPref = 'encryption_key';
  static const String lockTypePref = 'lock_type';
  static const String pinCodePref = 'pin_code';
  static const String flipToLockPref = 'flip_to_lock';
  static const String darkModePref = 'dark_mode';
  static const String notificationsEnabledPref = 'notifications_enabled';
  
  // WebRTC
  static const int dataChannelChunkSize = 16384; // 16KB
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int connectionTimeoutSeconds = 30;
  
  // ICE Servers (STUN/TURN)
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
  ];
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double avatarRadius = 28.0;
  static const double messageBubbleRadius = 16.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration signalingTimeout = Duration(seconds: 60);
  static const Duration typingIndicatorDelay = Duration(milliseconds: 500);
  static const Duration messageResendDelay = Duration(seconds: 5);
}

class ErrorMessages {
  static const String connectionFailed = 'Failed to establish connection';
  static const String messageSendFailed = 'Failed to send message';
  static const String fileTooLarge = 'File size exceeds 100MB limit';
  static const String invalidPhoneNumber = 'Please enter a valid phone number';
  static const String invalidOTP = 'Invalid OTP code';
  static const String authenticationFailed = 'Authentication failed';
  static const String userNotFound = 'User not found';
  static const String permissionDenied = 'Permission denied';
  static const String networkError = 'Network error. Please check your connection';
  static const String unknownError = 'An unknown error occurred';
}

class SuccessMessages {
  static const String messageSent = 'Message sent';
  static const String friendRequestSent = 'Friend request sent';
  static const String friendRequestAccepted = 'Friend request accepted';
  static const String settingsSaved = 'Settings saved';
  static const String pinSet = 'PIN code set successfully';
  static const String dataCleared = 'All data cleared';
}
