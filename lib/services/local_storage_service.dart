import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';
import '../models/chat_session_model.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';

class LocalStorageService {
  late Box<MessageModel> _messagesBox;
  late Box<ChatSessionModel> _sessionsBox;
  late Box<UserModel> _usersBox;
  late Box<FriendRequestModel> _requestsBox;
  late Box _settingsBox;
  
  late encrypt.Encrypter _encrypter;
  late encrypt.IV _iv;
  
  static const String _encryptionKeyPref = 'encryption_key';
  static const int _chunkSize = 65536; // 64KB chunks for file transfer

  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(MessageModelAdapter());
    Hive.registerAdapter(ChatSessionModelAdapter());
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(FriendRequestModelAdapter());
    Hive.registerAdapter(MessageTypeAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(RequestStatusAdapter());
    
    // Open boxes
    _messagesBox = await Hive.openBox<MessageModel>('messages');
    _sessionsBox = await Hive.openBox<ChatSessionModel>('sessions');
    _usersBox = await Hive.openBox<UserModel>('users');
    _requestsBox = await Hive.openBox<FriendRequestModel>('requests');
    _settingsBox = await Hive.openBox('settings');
    
    // Initialize encryption
    await _initializeEncryption();
  }

  Future<void> _initializeEncryption() async {
    String? keyString = _settingsBox.get(_encryptionKeyPref);
    
    if (keyString == null) {
      // Generate new encryption key
      final key = encrypt.Key.fromSecureRandom(32);
      keyString = base64Encode(key.bytes);
      await _settingsBox.put(_encryptionKeyPref, keyString);
    }
    
    final key = encrypt.Key.fromBase64(keyString);
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  }

  String _encrypt(String plainText) {
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }

  String _decrypt(String encryptedText) {
    return _encrypter.decrypt64(encryptedText, iv: _iv);
  }

  // Messages
  Future<void> saveMessage(MessageModel message) async {
    // Encrypt content before saving
    if (message.content != null && message.isEncrypted) {
      final encrypted = _encrypt(message.content!);
      message = message.copyWith(content: encrypted);
    }
    
    await _messagesBox.put(message.id, message);
    
    // Update session
    await _updateSessionWithMessage(message);
  }

  Future<MessageModel?> getMessage(String messageId) async {
    final message = _messagesBox.get(messageId);
    if (message == null) return null;
    
    // Decrypt content
    if (message.content != null && message.isEncrypted) {
      final decrypted = _decrypt(message.content!);
      return message.copyWith(content: decrypted);
    }
    
    return message;
  }

  List<MessageModel> getMessagesForChat(String peerId, {int limit = 100}) {
    final messages = _messagesBox.values
        .where((m) => m.senderId == peerId || m.receiverId == peerId)
        .toList();
    
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Decrypt messages
    return messages.map((m) {
      if (m.content != null && m.isEncrypted) {
        try {
          final decrypted = _decrypt(m.content!);
          return m.copyWith(content: decrypted);
        } catch (e) {
          return m;
        }
      }
      return m;
    }).toList();
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final message = _messagesBox.get(messageId);
    if (message != null) {
      await _messagesBox.put(messageId, message.copyWith(status: status));
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _messagesBox.delete(messageId);
  }

  // Chat Sessions
  Future<void> _updateSessionWithMessage(MessageModel message) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    final peerId = message.senderId == userId
        ? message.receiverId
        : message.senderId;

    final sessionId = _generateSessionId(userId, peerId);
    var session = _sessionsBox.get(sessionId);
    
    if (session == null) {
      session = ChatSessionModel(
        id: sessionId,
        peerId: peerId,
        createdAt: DateTime.now(),
        messageIds: [message.id],
      );
    } else {
      final messageIds = [...session.messageIds, message.id];
      session = session.copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        messageIds: messageIds,
        unreadCount: message.senderId == peerId 
            ? session.unreadCount + 1 
            : session.unreadCount,
      );
    }
    
    await _sessionsBox.put(sessionId, session);
  }

  String _generateSessionId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    final combined = sorted.join('_');
    return sha256.convert(utf8.encode(combined)).toString();
  }

  String? _getCurrentUserId() => FirebaseAuth.instance.currentUser?.uid;

  List<ChatSessionModel> getAllSessions() {
    return _sessionsBox.values.toList()
      ..sort((a, b) => (b.lastMessageTime ?? b.createdAt)
          .compareTo(a.lastMessageTime ?? a.createdAt));
  }

  Future<void> updateSession(ChatSessionModel session) async {
    await _sessionsBox.put(session.id, session);
  }

  Future<void> markSessionAsRead(String sessionId) async {
    final session = _sessionsBox.get(sessionId);
    if (session != null) {
      await _sessionsBox.put(sessionId, session.copyWith(unreadCount: 0));
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final session = _sessionsBox.get(sessionId);
    if (session != null) {
      // Delete all messages in session
      for (final messageId in session.messageIds) {
        await deleteMessage(messageId);
      }
      await _sessionsBox.delete(sessionId);
    }
  }

  // Users
  Future<void> saveUser(UserModel user) async {
    await _usersBox.put(user.uid, user);
  }

  UserModel? getUser(String userId) {
    return _usersBox.get(userId);
  }

  List<UserModel> getAllUsers() {
    return _usersBox.values.toList();
  }

  // Friend Requests
  Future<void> saveFriendRequest(FriendRequestModel request) async {
    await _requestsBox.put(request.id, request);
  }

  List<FriendRequestModel> getPendingRequests() {
    return _requestsBox.values
        .where((r) => r.status == RequestStatus.pending)
        .toList();
  }

  List<FriendRequestModel> getRequestsForUser(String userId) {
    return _requestsBox.values
        .where((r) => r.receiverId == userId || r.senderId == userId)
        .toList();
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    final request = _requestsBox.get(requestId);
    if (request != null) {
      await _requestsBox.put(
        requestId,
        request.copyWith(
          status: status,
          respondedAt: DateTime.now(),
        ),
      );
    }
  }

  // File Storage
  Future<String> saveFile(String fileName, Uint8List data, String chatId) async {
    final directory = await _getChatFilesDirectory(chatId);
    final filePath = '${directory.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(data);
    
    return filePath;
  }

  Future<Directory> _getChatFilesDirectory(String chatId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${appDir.path}/files/$chatId');
    
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }
    
    return chatDir;
  }

  Future<Uint8List?> readFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<int>> readFileChunk(String filePath, int offset, int length) async {
    final file = File(filePath);
    final raf = await file.open(mode: FileMode.read);
    
    await raf.setPosition(offset);
    final chunk = await raf.read(length);
    await raf.close();
    
    return chunk;
  }

  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  // Settings
  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  Future<void> clearAllData() async {
    await _messagesBox.clear();
    await _sessionsBox.clear();
    await _usersBox.clear();
    await _requestsBox.clear();
  }

  Future<void> dispose() async {
    await _messagesBox.close();
    await _sessionsBox.close();
    await _usersBox.close();
    await _requestsBox.close();
    await _settingsBox.close();
  }
}
