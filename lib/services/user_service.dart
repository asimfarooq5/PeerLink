import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getUsername(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['username'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> setUsername(String uid, String username, {String? displayName, String? photoURL}) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'username': username,
      if (displayName != null) 'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson({'uid': uid, ...doc.data()!});
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(20)
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromJson({'uid': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
