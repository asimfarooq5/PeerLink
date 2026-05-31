import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  final LocalStorageService _localStorage;
  
  StreamSubscription? _requestsSubscription;
  
  final _requestController = StreamController<FriendRequestModel>.broadcast();
  Stream<FriendRequestModel> get requestStream => _requestController.stream;

  FriendService(this._authService, this._localStorage);

  Future<void> initialize() async {
    _listenForRequests();
  }

  void _listenForRequests() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    // Listen for incoming friend requests
    _requestsSubscription = _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final request = FriendRequestModel.fromJson({
              'id': change.doc.id,
              ...data,
            });
            
            // Save to local storage
            await _localStorage.saveFriendRequest(request);
            _requestController.add(request);
          }
        }
      }
    });
  }

  // Search user by phone number
  Future<UserModel?> searchByPhoneNumber(String phoneNumber) async {
    final snapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return UserModel.fromJson({
      'uid': snapshot.docs.first.id,
      ...data,
    });
  }

  // Search user by username
  Future<UserModel?> searchByUsername(String username) async {
    final normalizedUsername = username.toLowerCase().trim();

    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalizedUsername)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return UserModel.fromJson({
      'uid': snapshot.docs.first.id,
      ...data,
    });
  }

  // Search user by phone or username
  Future<UserModel?> searchUser(String query) async {
    final trimmedQuery = query.trim();

    // Try phone number search first (if query starts with + or is all digits)
    if (trimmedQuery.startsWith('+') || RegExp(r'^\d+$').hasMatch(trimmedQuery)) {
      final phoneResult = await searchByPhoneNumber(trimmedQuery);
      if (phoneResult != null) return phoneResult;
    }

    // Try username search (remove @ if present)
    final usernameQuery = trimmedQuery.startsWith('@')
        ? trimmedQuery.substring(1)
        : trimmedQuery;

    return await searchByUsername(usernameQuery);
  }

  // Send friend request
  Future<FriendRequestModel?> sendFriendRequest(
    String receiverId, {
    String? message,
  }) async {
    final senderId = _authService.currentUser?.uid;
    if (senderId == null) return null;

    // Prevent sending request to yourself
    if (senderId == receiverId) {
      throw Exception('Cannot send friend request to yourself');
    }

    // Check if already friends or request pending
    final existingRequest = await _checkExistingRequest(senderId, receiverId);
    if (existingRequest != null) return existingRequest;
    
    final request = FriendRequestModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      status: RequestStatus.pending,
      sentAt: DateTime.now(),
      message: message,
    );
    
    final docRef = await _firestore.collection('friend_requests').add(request.toJson());
    
    final requestWithId = FriendRequestModel(
      id: docRef.id,
      senderId: senderId,
      receiverId: receiverId,
      status: RequestStatus.pending,
      sentAt: request.sentAt,
      message: message,
    );
    
    await _localStorage.saveFriendRequest(requestWithId);
    
    // Send FCM notification to receiver
    await _sendRequestNotification(receiverId);
    
    return requestWithId;
  }

  Future<FriendRequestModel?> _checkExistingRequest(String senderId, String receiverId) async {
    final snapshot = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return FriendRequestModel.fromJson({
        'id': snapshot.docs.first.id,
        ...data,
      });
    }
    
    // Check reverse direction
    final reverseSnapshot = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: receiverId)
        .where('receiverId', isEqualTo: senderId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    
    if (reverseSnapshot.docs.isNotEmpty) {
      final data = reverseSnapshot.docs.first.data();
      return FriendRequestModel.fromJson({
        'id': reverseSnapshot.docs.first.id,
        ...data,
      });
    }
    
    return null;
  }

  Future<void> _sendRequestNotification(String receiverId) async {
    // Get receiver's FCM token
    final userDoc = await _firestore.collection('users').doc(receiverId).get();
    final fcmToken = userDoc.data()?['fcmToken'] as String?;
    
    if (fcmToken != null) {
      // Send FCM notification via cloud function or directly
      // This would typically be handled by a cloud function
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    if (_authService.currentUser?.uid == null) return;

    final doc = await _firestore.collection('friend_requests').doc(requestId).get();
    if (!doc.exists) return;

    await doc.reference.update({
      'status': 'accepted',
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final data = doc.data()!;
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;

    await _localStorage.updateRequestStatus(requestId, RequestStatus.accepted);
    await _addToFriendsList(senderId, receiverId);
    await _addToFriendsList(receiverId, senderId);
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _localStorage.updateRequestStatus(requestId, RequestStatus.rejected);
  }

  Future<void> _addToFriendsList(String userId, String friendId) async {
    await _firestore.collection('users').doc(userId).collection('friends').doc(friendId).set({
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get friends list
  Future<List<UserModel>> getFriends() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return [];
    
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .get();
    
    final friends = <UserModel>[];
    
    for (final doc in friendsSnapshot.docs) {
      final friendId = doc.id;
      final userDoc = await _firestore.collection('users').doc(friendId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        friends.add(UserModel.fromJson({
          'uid': friendId,
          ...data,
        }));
      }
    }
    
    return friends;
  }

  // Remove friend
  Future<void> removeFriend(String friendId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .doc(friendId)
        .delete();
    
    await _firestore
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(userId)
        .delete();
  }

  // Block user
  Future<void> blockUser(String userId) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(userId)
        .set({
      'blockedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get pending requests from Firestore (authoritative)
  Future<List<FriendRequestModel>> fetchPendingRequests() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final requests = <FriendRequestModel>[];
    for (final doc in snapshot.docs) {
      final request = FriendRequestModel.fromJson({'id': doc.id, ...doc.data()});
      await _localStorage.saveFriendRequest(request);
      requests.add(request);
    }
    return requests;
  }

  // Get user info by uid
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson({'uid': uid, ...doc.data()!});
  }

  // Get pending requests (local cache)
  List<FriendRequestModel> getPendingRequests() {
    return _localStorage.getPendingRequests();
  }

  Future<void> dispose() async {
    await _requestsSubscription?.cancel();
    _requestController.close();
  }
}
