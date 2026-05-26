import 'package:hive/hive.dart';

part 'friend_request_model.g.dart';

enum RequestStatus {
  pending,
  accepted,
  rejected,
  blocked,
}

@HiveType(typeId: 3)
class FriendRequestModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String senderId;
  
  @HiveField(2)
  final String receiverId;
  
  @HiveField(3)
  final RequestStatus status;
  
  @HiveField(4)
  final DateTime sentAt;
  
  @HiveField(5)
  final DateTime? respondedAt;
  
  @HiveField(6)
  final String? message;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.status = RequestStatus.pending,
    required this.sentAt,
    this.respondedAt,
    this.message,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      status: RequestStatus.values.byName(json['status'] as String),
      sentAt: DateTime.fromMillisecondsSinceEpoch(json['sentAt'] as int),
      respondedAt: json['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['respondedAt'] as int)
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.name,
      'sentAt': sentAt.millisecondsSinceEpoch,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
      'message': message,
    };
  }

  FriendRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    RequestStatus? status,
    DateTime? sentAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }
}
