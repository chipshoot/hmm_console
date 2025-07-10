import '../../domain/entities/message.dart';

// lib/features/home/data/models/message_model.dart
class MessageModel extends Message {
  MessageModel({
    required String id,
    required String sender,
    required String avatar,
    required String preview,
    required String time,
    required bool isUnread,
  }) : super(
         id: id,
         sender: sender,
         avatar: avatar,
         preview: preview,
         time: time,
         isUnread: isUnread,
       );

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      sender: json['sender'],
      avatar: json['avatar'],
      preview: json['preview'],
      time: json['time'],
      isUnread: json['isUnread'] ?? false,
    );
  }
}
