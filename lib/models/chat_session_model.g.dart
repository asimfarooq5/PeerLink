// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionModelAdapter extends TypeAdapter<ChatSessionModel> {
  @override
  final int typeId = 4;

  @override
  ChatSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSessionModel(
      id: fields[0] as String,
      peerId: fields[1] as String,
      peerName: fields[2] as String?,
      peerPhotoUrl: fields[3] as String?,
      lastMessage: fields[4] as String?,
      lastMessageTime: fields[5] as DateTime?,
      unreadCount: fields[6] as int,
      isP2PConnected: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      messageIds: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatSessionModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.peerId)
      ..writeByte(2)
      ..write(obj.peerName)
      ..writeByte(3)
      ..write(obj.peerPhotoUrl)
      ..writeByte(4)
      ..write(obj.lastMessage)
      ..writeByte(5)
      ..write(obj.lastMessageTime)
      ..writeByte(6)
      ..write(obj.unreadCount)
      ..writeByte(7)
      ..write(obj.isP2PConnected)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.messageIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
