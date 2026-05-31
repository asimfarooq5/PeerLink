import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Always use FirebaseAuth directly — synchronous and never null when signed in
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> initialize() async {
    _listenForRequests();
  }

  void _listenForRequests() {
    final userId = _uid;
    if (userId == null) return;

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
            // Put 'id' AFTER the spread so doc.id wins over the stored empty string
            final request = FriendRequestModel.fromJson({...data, 'id': change.doc.id});
            await _localStorage.saveFriendRequest(request);
            _requestController.add(request);
          }
        }
      }
    });
  }

  Future<UserModel?> searchByPhoneNumber(String phoneNumber) async {
    final snapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return UserModel.fromJson({...snapshot.docs.first.data(), 'uid': snapshot.docs.first.id});
  }

  Future<UserModel?> searchByUsername(String username) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return UserModel.fromJson({...snapshot.docs.first.data(), 'uid': snapshot.docs.first.id});
  }

  Future<UserModel?> searchUser(String query) async {
    final trimmed = query.trim();
    if (trimmed.startsWith('+') || RegExp(r'^\d+$').hasMatch(trimmed)) {
      final result = await searchByPhoneNumber(trimmed);
      if (result != null) return result;
    }
    final usernameQuery = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return searchByUsername(usernameQuery);
  }

  Future<FriendRequestModel?> sendFriendRequest(String receiverId, {String? message}) async {
    final senderId = _uid;
    if (senderId == null) return null;

    if (senderId == receiverId) throw Exception('Cannot send friend request to yourself');

    final existing = await _checkExistingRequest(senderId, receiverId);
    if (existing != null) return existing;

    final request = FriendRequestModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      status: RequestStatus.pending,
      sentAt: DateTime.now(),
      message: message,
    );

    final docRef = await _firestore.collection('friend_requests').add(request.toJson());

    final requestWithId = request.copyWith(id: docRef.id);
    await _localStorage.saveFriendRequest(requestWithId);
    await _sendRequestNotification(receiverId);
    return requestWithId;
  }

  Future<FriendRequestModel?> _checkExistingRequest(String senderId, String receiverId) async {
    for (final query in [
      _firestore.collection('friend_requests')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .limit(1),
      _firestore.collection('friend_requests')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: senderId)
          .where('status', isEqualTo: 'pending')
          .limit(1),
    ]) {
      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return FriendRequestModel.fromJson({...doc.data(), 'id': doc.id});
      }
    }
    return null;
  }

  Future<void> _sendRequestNotification(String receiverId) async {
    final userDoc = await _firestore.collection('users').doc(receiverId).get();
    final fcmToken = userDoc.data()?['fcmToken'] as String?;
    if (fcmToken != null) {
      // Handled by cloud function
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    if (_uid == null) throw Exception('Not authenticated');

    final doc = await _firestore.collection('friend_requests').doc(requestId).get();
    if (!doc.exists) throw Exception('Friend request not found');

    final data = doc.data()!;
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;

    await doc.reference.update({
      'status': 'accepted',
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await _localStorage.updateRequestStatus(requestId, RequestStatus.accepted);
    await _addToFriendsList(senderId, receiverId);
    await _addToFriendsList(receiverId, senderId);
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _localStorage.updateRequestStatus(requestId, RequestStatus.rejected);
  }

  Future<void> _addToFriendsList(String userId, String friendId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .doc(friendId)
        .set({'addedAt': DateTime.now().millisecondsSinceEpoch});
  }

  Future<List<UserModel>> getFriends() async {
    final userId = _uid;
    if (userId == null) return [];

    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .get();

    final friends = <UserModel>[];
    for (final doc in friendsSnapshot.docs) {
      final userDoc = await _firestore.collection('users').doc(doc.id).get();
      if (userDoc.exists && userDoc.data() != null) {
        friends.add(UserModel.fromJson({...userDoc.data()!, 'uid': doc.id}));
      }
    }
    return friends;
  }

  Future<List<FriendRequestModel>> fetchPendingRequests() async {
    final userId = _uid;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final requests = <FriendRequestModel>[];
    for (final doc in snapshot.docs) {
      // Put 'id' AFTER the spread so the real Firestore doc ID wins
      final request = FriendRequestModel.fromJson({...doc.data(), 'id': doc.id});
      await _localStorage.saveFriendRequest(request);
      requests.add(request);
    }
    return requests;
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson({...doc.data()!, 'uid': uid});
  }

  List<FriendRequestModel> getPendingRequests() => _localStorage.getPendingRequests();

  Future<void> removeFriend(String friendId) async {
    final userId = _uid;
    if (userId == null) return;
    await _firestore.collection('users').doc(userId).collection('friends').doc(friendId).delete();
    await _firestore.collection('users').doc(friendId).collection('friends').doc(userId).delete();
  }

  Future<void> dispose() async {
    await _requestsSubscription?.cancel();
    _requestController.close();
  }
}
