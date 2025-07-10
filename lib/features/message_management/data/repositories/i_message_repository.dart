import '../models/message_model.dart';

abstract class IMessageRepository {
  Future<List<MessageModel>> getMessages();

  Future<void> markAsRead(String messageId);

  Stream<List<MessageModel>> watchMessages();
}
