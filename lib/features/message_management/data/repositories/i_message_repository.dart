import '../../domain/entities/message.dart';

abstract class IMessageRepository {
  Future<List<Message>> getMessages();

  Future<void> markAsRead(String messageId);

  Stream<List<Message>> watchMessages();
}
