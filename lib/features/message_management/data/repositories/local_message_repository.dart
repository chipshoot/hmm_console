import '../../domain/entities/message.dart';
import "i_message_repository.dart";

class LocalMessageRepository implements IMessageRepository {
  final List<Message> _messages = [
    Message(
      id: "1",
      sender: "John Doe",
      avatar: "JD",
      preview: "Hey! Don't forget about our meeting tomorrow at 2 PM",
      time: "2m",
      isUnread: true,
    ),
    Message(
      id: "2",
      sender: "Sarah Miller",
      avatar: "SM",
      preview: "The project update looks great! Let's discuss the next steps",
      time: "15m",
      isUnread: true,
    ),
    Message(
      id: "3",
      sender: "Mike Johnson",
      avatar: "MJ",
      preview: "Thanks for sharing the documents. I'll review them today",
      time: "1h",
      isUnread: false,
    ),
  ];

  @override
  Future<List<Message>> getMessages() async {
    // Simulate a delay to mimic network/database access
    await Future.delayed(Duration(milliseconds: 500));
    return List.from(_messages);
  }

  @override
  Future<void> markAsRead(String messageId) async {
    await Future.delayed(Duration(milliseconds: 200));
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(isUnread: false);
    }
  }

  @override
  Stream<List<Message>> watchMessages() {
    // Simulate a stream of messages
    return Stream.periodic(
      const Duration(seconds: 1),
      (count) => List.from(_messages),
    );
  }
}
