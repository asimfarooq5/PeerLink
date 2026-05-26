import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel extends HiveObject {
  @HiveField(0)
  final String uid;
  
  @HiveField(1)
  final String? phoneNumber;
  
  @HiveField(2)
  final String? displayName;
  
  @HiveField(3)
  final String? photoURL;
  
  @HiveField(4)
  final String? fcmToken;
  
  @HiveField(5)
  final bool isOnline;
  
  @HiveField(6)
  final DateTime? lastSeen;
  
  @HiveField(7)
  final String? publicKey;

  UserModel({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
    this.fcmToken,
    this.isOnline = false,
    this.lastSeen,
    this.publicKey,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      fcmToken: json['fcmToken'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int)
          : null,
      publicKey: json['publicKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoURL': photoURL,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'publicKey': publicKey,
    };
  }

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? photoURL,
    String? fcmToken,
    bool? isOnline,
    DateTime? lastSeen,
    String? publicKey,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      publicKey: publicKey ?? this.publicKey,
    );
  }
}
