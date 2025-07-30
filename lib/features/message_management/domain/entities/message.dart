class Message {
  final String id;
  final String sender;
  final String avatar;
  final String preview;
  final String time;
  final bool isUnread;
  final String? conversationId;
  final String? content;

  Message({
    required this.id,
    required this.sender,
    required this.avatar,
    required this.preview,
    required this.time,
    this.isUnread = false,
    this.conversationId = '',
    this.content = '',
  });

  Message copyWith({
    String? id,
    String? sender,
    String? avatar,
    String? prview,
    String? time,
    bool? isUnread,
    String? conversationId,
    String? content,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      avatar: avatar ?? this.avatar,
      preview: prview ?? preview,
      time: time ?? this.time,
      isUnread: isUnread ?? this.isUnread,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
    );
  }
}
