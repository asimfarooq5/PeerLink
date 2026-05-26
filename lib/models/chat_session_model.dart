import 'package:hive/hive.dart';
import 'message_model.dart';

part 'chat_session_model.g.dart';

@HiveType(typeId: 4)
class ChatSessionModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String peerId;
  
  @HiveField(2)
  final String? peerName;
  
  @HiveField(3)
  final String? peerPhotoUrl;
  
  @HiveField(4)
  final String? lastMessage;
  
  @HiveField(5)
  final DateTime? lastMessageTime;
  
  @HiveField(6)
  final int unreadCount;
  
  @HiveField(7)
  final bool isP2PConnected;
  
  @HiveField(8)
  final DateTime createdAt;
  
  @HiveField(9)
  final List<String> messageIds;

  ChatSessionModel({
    required this.id,
    required this.peerId,
    this.peerName,
    this.peerPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isP2PConnected = false,
    required this.createdAt,
    this.messageIds = const [],
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      id: json['id'] as String,
      peerId: json['peerId'] as String,
      peerName: json['peerName'] as String?,
      peerPhotoUrl: json['peerPhotoUrl'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastMessageTime'] as int)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isP2PConnected: json['isP2PConnected'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      messageIds: (json['messageIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peerId': peerId,
      'peerName': peerName,
      'peerPhotoUrl': peerPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'isP2PConnected': isP2PConnected,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'messageIds': messageIds,
    };
  }

  ChatSessionModel copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? peerPhotoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isP2PConnected,
    DateTime? createdAt,
    List<String>? messageIds,
  }) {
    return ChatSessionModel(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerPhotoUrl: peerPhotoUrl ?? this.peerPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isP2PConnected: isP2PConnected ?? this.isP2PConnected,
      createdAt: createdAt ?? this.createdAt,
      messageIds: messageIds ?? this.messageIds,
    );
  }
}
