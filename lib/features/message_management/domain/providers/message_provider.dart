import '../entities/message.dart';
import 'i_message_provider.dart';
import '../../data/repositories/i_message_repository.dart';

class MessageProvider implements IMessageProvider {
  final IMessageRepository _messageRepository;

  MessageProvider(this._messageRepository);

  @override
  Future<List<Message>> getRecentMessages({int limit = 10}) async {
    final messages = await _messageRepository.getMessages();
    return messages.take(limit).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final messages = await _messageRepository.getMessages();
    return messages.where((message) => message.isUnread).length;
  }

  @override
  Future<void> markMessageAsRead(String messageId) async {
    await _messageRepository.markAsRead(messageId);
  }

  @override
  Stream<List<Message>> watchRecentMessage() {
    return _messageRepository.watchMessages().map(
      (messages) => messages.take(10).toList(),
    );
  }

  @override
  Stream<int> watchUnreadCount() {
    return _messageRepository.watchMessages().map(
      (messages) => messages.where((message) => message.isUnread).length,
    );
  }

  @override
  Future<List<Message>> getMesageByConversation(String conversationId) async {
    // Get all messages from repository
    // In a real implementation, you would filter by conversationId
    final messages = await _messageRepository.getMessages();
    return messages;
  }

  @override
  Future<void> sendMessage(String conversationId, String content) async {
    // In a real implementation, this would send the message through the repository
    // For now, we'll just simulate the operation
    await Future.delayed(const Duration(milliseconds: 600));

    // The actual sending would be handled by the repository
    // which might trigger updates that come through the watchMessages stream
  }
}
