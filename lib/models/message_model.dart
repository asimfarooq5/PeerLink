import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 10)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  audio,
  @HiveField(4)
  file,
  @HiveField(5)
  location,
}

@HiveType(typeId: 11)
enum MessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  delivered,
  @HiveField(3)
  read,
  @HiveField(4)
  failed,
}

@HiveType(typeId: 2)
class MessageModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String senderId;
  
  @HiveField(2)
  final String receiverId;
  
  @HiveField(3)
  final String? content;
  
  @HiveField(4)
  final MessageType type;
  
  @HiveField(5)
  final DateTime timestamp;
  
  @HiveField(6)
  final MessageStatus status;
  
  @HiveField(7)
  final String? filePath;
  
  @HiveField(8)
  final String? fileName;
  
  @HiveField(9)
  final int? fileSize;
  
  @HiveField(10)
  final String? mediaUrl;
  
  @HiveField(11)
  final double? latitude;
  
  @HiveField(12)
  final double? longitude;
  
  @HiveField(13)
  final String? replyToMessageId;
  
  @HiveField(14)
  final bool isEncrypted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.mediaUrl,
    this.latitude,
    this.longitude,
    this.replyToMessageId,
    this.isEncrypted = true,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String?,
      type: MessageType.values.byName(json['type'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      status: MessageStatus.values.byName(json['status'] as String),
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      mediaUrl: json['mediaUrl'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      replyToMessageId: json['replyToMessageId'] as String?,
      isEncrypted: json['isEncrypted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mediaUrl': mediaUrl,
      'latitude': latitude,
      'longitude': longitude,
      'replyToMessageId': replyToMessageId,
      'isEncrypted': isEncrypted,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    MessageStatus? status,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mediaUrl,
    double? latitude,
    double? longitude,
    String? replyToMessageId,
    bool? isEncrypted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
