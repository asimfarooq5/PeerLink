import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart' as models;
import 'auth_service.dart';
import 'webrtc_service.dart';
import 'signaling_service.dart';
import 'local_storage_service.dart';

class ChatService {
  final AuthService _authService;
  final WebRTCService _webRTCService;
  final SignalingService _signalingService;
  final LocalStorageService _localStorage;
  
  final _uuid = const Uuid();
  
  final _connectionStateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get connectionStateStream => _connectionStateController.stream;
  
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  
  String? _currentPeerId;
  bool _isTyping = false;

  ChatService(
    this._authService,
    this._webRTCService,
    this._signalingService,
    this._localStorage,
  );

  Future<void> initialize() async {
    // Listen for WebRTC messages
    _webRTCService.messageStream.listen(_handleIncomingMessage);

    // Listen for signaling
    _signalingService.signalStream.listen(_handleSignalingMessage);

    // Forward ICE candidates to peer via signaling
    _webRTCService.iceCandidateStream.listen((candidate) {
      if (_currentPeerId != null) {
        _signalingService.sendIceCandidate(_currentPeerId!, candidate);
      }
    });

    // Listen for connection state changes
    _webRTCService.connectionStateStream.listen((state) {
      _connectionStateController.add({
        'peerId': _currentPeerId,
        'state': state,
      });
    });

    // Listen for file progress
    _webRTCService.fileProgressStream.listen((progress) {
      // Handle file transfer progress
    });
  }

  // Connect to peer
  Future<void> connectToPeer(String peerId) async {
    _currentPeerId = peerId;
    
    // Send wakeup signal
    await _signalingService.sendWakeup(peerId);
    
    // Initialize WebRTC
    await _webRTCService.initialize();
    
    // Create and send offer
    final offer = await _webRTCService.createOffer();
    await _signalingService.sendOffer(peerId, offer);
  }

  // Handle incoming signaling messages
  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    if (message.receiverId != _authService.currentUser?.uid) return;
    
    switch (message.type) {
      case 'offer':
        await _handleOffer(message.senderId, message.data);
        break;
      case 'answer':
        await _handleAnswer(message.data);
        break;
      case 'ice':
        await _handleIceCandidate(message.data);
        break;
      case 'wakeup':
        // Auto-accept connection from known friends
        await _handleWakeup(message.senderId);
        break;
      case 'typing':
        final data = message.data as Map<String, dynamic>;
        _typingController.add({
          'peerId': message.senderId,
          'isTyping': (data['isTyping'] as bool?) ?? false,
        });
        break;
    }
  }

  Future<void> _handleOffer(String senderId, dynamic data) async {
    _currentPeerId = senderId;
    
    await _webRTCService.initialize();
    
    final offer = RTCSessionDescription(
      data['sdp'] as String,
      data['type'] as String,
    );
    
    final answer = await _webRTCService.createAnswer(offer);
    await _signalingService.sendAnswer(senderId, answer);
  }

  Future<void> _handleAnswer(dynamic data) async {
    final answer = RTCSessionDescription(
      data['sdp'] as String,
      data['type'] as String,
    );
    
    await _webRTCService.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    
    await _webRTCService.addIceCandidate(candidate);
  }

  Future<void> _handleWakeup(String senderId) async {
    // Check if sender is a friend by looking up in local storage
    final user = _localStorage.getUser(senderId);
    
    if (user != null) {
      await connectToPeer(senderId);
    }
  }

  // Send text message
  Future<models.MessageModel> sendTextMessage(String peerId, String text, {String? replyToId}) async {
    final message = models.MessageModel(
      id: _uuid.v4(),
      senderId: _authService.currentUser!.uid,
      receiverId: peerId,
      content: text,
      type: models.MessageType.text,
      timestamp: DateTime.now(),
      status: models.MessageStatus.sending,
      replyToMessageId: replyToId,
    );
    
    // Save locally first
    await _localStorage.saveMessage(message);
    
    // Send via WebRTC if connected
    try {
      await _webRTCService.sendMessage(message);
      await _localStorage.updateMessageStatus(message.id, models.MessageStatus.sent);
    } catch (e) {
      print('Failed to send message: $e');
      await _localStorage.updateMessageStatus(message.id, models.MessageStatus.failed);
    }
    
    return message;
  }

  // Send image
  Future<models.MessageModel?> sendImage(String peerId, {ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    
    if (pickedFile == null) return null;
    
    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final fileName = pickedFile.name;
    
    // Save file locally
    final savedPath = await _localStorage.saveFile(fileName, bytes, peerId);
    
    final message = models.MessageModel(
      id: _uuid.v4(),
      senderId: _authService.currentUser!.uid,
      receiverId: peerId,
      type: models.MessageType.image,
      timestamp: DateTime.now(),
      status: models.MessageStatus.sending,
      filePath: savedPath,
      fileName: fileName,
      fileSize: bytes.length,
    );
    
    await _localStorage.saveMessage(message);
    
    // Send file via WebRTC data channel
    await _sendFileInChunks(message.id, bytes);
    
    return message;
  }

  // Send video
  Future<models.MessageModel?> sendVideo(String peerId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    
    if (pickedFile == null) return null;
    
    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final fileName = pickedFile.name;
    
    final savedPath = await _localStorage.saveFile(fileName, bytes, peerId);
    
    final message = models.MessageModel(
      id: _uuid.v4(),
      senderId: _authService.currentUser!.uid,
      receiverId: peerId,
      type: models.MessageType.video,
      timestamp: DateTime.now(),
      status: models.MessageStatus.sending,
      filePath: savedPath,
      fileName: fileName,
      fileSize: bytes.length,
    );
    
    await _localStorage.saveMessage(message);
    await _sendFileInChunks(message.id, bytes);
    
    return message;
  }

  // Send file
  Future<models.MessageModel?> sendFile(String peerId) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    
    if (result == null || result.files.isEmpty) return null;
    
    final pickedFile = result.files.first;
    final bytes = pickedFile.bytes;
    
    if (bytes == null) return null;
    
    final fileName = pickedFile.name;
    final savedPath = await _localStorage.saveFile(fileName, bytes, peerId);
    
    final message = models.MessageModel(
      id: _uuid.v4(),
      senderId: _authService.currentUser!.uid,
      receiverId: peerId,
      type: models.MessageType.file,
      timestamp: DateTime.now(),
      status: models.MessageStatus.sending,
      filePath: savedPath,
      fileName: fileName,
      fileSize: bytes.length,
    );
    
    await _localStorage.saveMessage(message);
    await _sendFileInChunks(message.id, bytes);
    
    return message;
  }

  // Send file in chunks via WebRTC
  Future<void> _sendFileInChunks(String fileId, Uint8List data) async {
    const chunkSize = 16384; // 16KB chunks
    final totalChunks = (data.length / chunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < data.length) ? start + chunkSize : data.length;
      final chunk = data.sublist(start, end);
      
      await _webRTCService.sendFileChunk(fileId, i, totalChunks, chunk);
    }
  }

  // Handle incoming messages
  void _handleIncomingMessage(models.MessageModel message) async {
    // Save to local storage
    await _localStorage.saveMessage(message.copyWith(
      status: models.MessageStatus.delivered,
    ));
    
    // Send read receipt
    _sendReadReceipt(message.id);
  }

  Future<void> _sendReadReceipt(String messageId) async {
    // Implementation for read receipts
  }

  // Typing indicators
  Future<void> setTypingStatus(String peerId, bool isTyping) async {
    if (_isTyping == isTyping) return;
    
    _isTyping = isTyping;
    
    await _signalingService.sendSignal(peerId, 'typing', {
      'isTyping': isTyping,
    });
  }

  // Get chat history
  List<models.MessageModel> getChatHistory(String peerId) {
    return _localStorage.getMessagesForChat(peerId);
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    await _localStorage.deleteMessage(messageId);
  }

  // Disconnect from peer
  Future<void> disconnect() async {
    _currentPeerId = null;
    await _webRTCService.dispose();
  }

  Future<void> dispose() async {
    await disconnect();
    _connectionStateController.close();
    _typingController.close();
  }
}
