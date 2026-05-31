import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'auth_service.dart';

class SignalingMessage {
  final String type;
  final String senderId;
  final String receiverId;
  final dynamic data;
  final DateTime timestamp;

  SignalingMessage({
    required this.type,
    required this.senderId,
    required this.receiverId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'senderId': senderId,
    'receiverId': receiverId,
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory SignalingMessage.fromJson(Map<String, dynamic> json) => SignalingMessage(
    type: json['type'] as String,
    senderId: json['senderId'] as String,
    receiverId: json['receiverId'] as String,
    data: json['data'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
  );
}

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _authService;
  
  StreamSubscription? _signalingSubscription;
  
  final _signalController = StreamController<SignalingMessage>.broadcast();
  Stream<SignalingMessage> get signalStream => _signalController.stream;
  
  final _wakeupController = StreamController<String>.broadcast();
  Stream<String> get wakeupStream => _wakeupController.stream;

  SignalingService(this._authService);

  Future<void> initialize() async {
    // Request notification permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _authService.updateFCMToken(token);
      await _updateUserToken(token);
    }
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) async {
      await _authService.updateFCMToken(token);
      await _updateUserToken(token);
    });
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleWakeupMessage(message);
    });
    
    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Listen for signaling messages
    _listenForSignaling();
  }

  Future<void> _updateUserToken(String token) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  void _listenForSignaling() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    _signalingSubscription = _firestore
        .collection('signaling')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final message = SignalingMessage.fromJson(data);
            // Always delete from Firestore
            change.doc.reference.delete();
            // Discard stale messages from previous sessions (> 30 s old)
            if (DateTime.now().difference(message.timestamp).inSeconds > 30) {
              continue;
            }
            _signalController.add(message);
          }
        }
      }
    });
  }

  void _handleWakeupMessage(RemoteMessage message) {
    final data = message.data;
    final senderId = data['senderId'] as String?;
    final type = data['type'] as String?;
    
    if (senderId != null && type == 'wakeup') {
      _wakeupController.add(senderId);
    }
  }

  Future<void> sendSignal(
    String receiverId,
    String type,
    dynamic data,
  ) async {
    final senderId = _authService.currentUser?.uid;
    if (senderId == null) return;
    
    final message = SignalingMessage(
      type: type,
      senderId: senderId,
      receiverId: receiverId,
      data: data,
      timestamp: DateTime.now(),
    );
    
    await _firestore
        .collection('signaling')
        .doc(receiverId)
        .collection('messages')
        .add(message.toJson());
  }

  Future<void> sendOffer(String receiverId, RTCSessionDescription offer) async {
    await sendSignal(receiverId, 'offer', {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> sendAnswer(String receiverId, RTCSessionDescription answer) async {
    await sendSignal(receiverId, 'answer', {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> sendIceCandidate(String receiverId, RTCIceCandidate candidate) async {
    await sendSignal(receiverId, 'ice', {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  Future<void> sendWakeup(String receiverId) async {
    await sendSignal(receiverId, 'wakeup', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Also send FCM notification for background wakeup
    final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
    final fcmToken = receiverDoc.data()?['fcmToken'] as String?;
    
    if (fcmToken != null) {
      // Call your cloud function to send FCM
      // Or use Firebase Cloud Messaging directly
    }
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    await _firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> dispose() async {
    await _signalingSubscription?.cancel();
    await setOnlineStatus(false);
    _signalController.close();
    _wakeupController.close();
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}
