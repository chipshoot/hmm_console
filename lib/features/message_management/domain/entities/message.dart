class Message {
  final String id;
  final String sender;
  final String avatar;
  final String preview;
  final String time;
  final bool isUnread;

  Message({
    required this.id,
    required this.sender,
    required this.avatar,
    required this.preview,
    required this.time,
    this.isUnread = false,
  });

  Message copyWith({
    String? id,
    String? sender,
    String? avatar,
    String? prview,
    String? time,
    bool? isUnread,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      avatar: avatar ?? this.avatar,
      preview: prview ?? preview,
      time: time ?? this.time,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}
