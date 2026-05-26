import 'dart:math';
import 'package:intl/intl.dart';

class Helpers {
  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Format timestamp
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == yesterday) {
      return 'Yesterday, ${DateFormat('HH:mm').format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEE, HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }

  // Format date for chat list
  static String formatChatListTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('MM/dd/yy').format(time);
    }
  }

  // Generate unique ID
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  // Validate phone number
  static bool isValidPhoneNumber(String phone) {
    // Basic validation - can be improved with libphonenumber
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 10 && cleaned.length <= 15;
  }

  // Format phone number for display
  static String formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    
    // Remove all non-digit characters except +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.startsWith('+')) {
      // International format
      if (cleaned.length >= 10) {
        return '+${cleaned.substring(1, cleaned.length - 7)} '
            '${cleaned.substring(cleaned.length - 7, cleaned.length - 4)} '
            '${cleaned.substring(cleaned.length - 4)}';
      }
    } else {
      // Local format
      if (cleaned.length == 10) {
        return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
      }
    }
    
    return cleaned;
  }

  // Get initials from name
  static String getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // Truncate text
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  // Check if file is image
  static bool isImage(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  // Check if file is video
  static bool isVideo(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(ext);
  }

  // Check if file is audio
  static bool isAudio(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac'].contains(ext);
  }

  // Get file icon based on extension
  static String getFileIcon(String fileName) {
    if (isImage(fileName)) return 'image';
    if (isVideo(fileName)) return 'video';
    if (isAudio(fileName)) return 'audio';
    
    final ext = fileName.toLowerCase().split('.').last;
    
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'document';
      case 'xls':
      case 'xlsx':
        return 'spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'presentation';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      case 'apk':
        return 'android';
      default:
        return 'file';
    }
  }

  // Calculate chunk count for file transfer
  static int calculateChunkCount(int fileSize, int chunkSize) {
    return (fileSize / chunkSize).ceil();
  }

  // Generate chat session ID from two user IDs
  static String generateSessionId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return sorted.join('_');
  }
}
