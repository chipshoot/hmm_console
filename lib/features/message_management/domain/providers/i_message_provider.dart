import '../entities/message.dart';

class IMessageProvider {
  Future<List<Message>> getRecentMessages({int limit = 10}) {
    return Future.value([]);
  }

  Future<int> getUnreadCount() {
    return Future.value(0);
  }

  Future<void> markMessageAsRead(String messageId) {
    return Future.value();
  }

  Stream<List<Message>> watchRecentMessage() {
    return Stream.value([]);
  }

  Stream<int> watchUnreadCount() {
    return Stream.value(0);
  }

  Future<List<Message>> getMesageByConversation(String conversationId) {
    return Future.value([]);
  }

  Future<void> sendMessage(String conversationId, String content) {
    return Future.value();
  }
}
