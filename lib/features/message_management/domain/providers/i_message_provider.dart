import '../entities/message.dart';

abstract class IMessageProvider {
  Future<List<Message>> getRecentMessages({int limit = 10});

  Future<int> getUnreadCount();

  Future<void> markMessageAsRead(String messageId);

  Stream<List<Message>> watchRecentMessage();

  Stream<int> watchUnreadCount();

  Future<List<Message>> getMesageByConversation(String conversationId);

  Future<void> sendMessage(String conversationId, String content);
}
