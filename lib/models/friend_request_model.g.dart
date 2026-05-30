// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FriendRequestModelAdapter extends TypeAdapter<FriendRequestModel> {
  @override
  final int typeId = 3;

  @override
  FriendRequestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FriendRequestModel(
      id: fields[0] as String,
      senderId: fields[1] as String,
      receiverId: fields[2] as String,
      status: fields[3] as RequestStatus,
      sentAt: fields[4] as DateTime,
      respondedAt: fields[5] as DateTime?,
      message: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FriendRequestModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.receiverId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.sentAt)
      ..writeByte(5)
      ..write(obj.respondedAt)
      ..writeByte(6)
      ..write(obj.message);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RequestStatusAdapter extends TypeAdapter<RequestStatus> {
  @override
  final int typeId = 12;

  @override
  RequestStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RequestStatus.pending;
      case 1:
        return RequestStatus.accepted;
      case 2:
        return RequestStatus.rejected;
      case 3:
        return RequestStatus.blocked;
      default:
        return RequestStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, RequestStatus obj) {
    switch (obj) {
      case RequestStatus.pending:
        writer.writeByte(0);
        break;
      case RequestStatus.accepted:
        writer.writeByte(1);
        break;
      case RequestStatus.rejected:
        writer.writeByte(2);
        break;
      case RequestStatus.blocked:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
