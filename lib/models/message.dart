class Message {
  final String sender;
  final String avatar;
  final String preview;
  final String time;
  final bool isUnread;

  Message({
    required this.sender,
    required this.avatar,
    required this.preview,
    required this.time,
    this.isUnread = false,
  });

  Message copyWith({
    String? sender,
    String? avatar,
    String? prview,
    String? time,
    bool? isUnread,
  }) {
    return Message(
      sender: sender ?? this.sender,
      avatar: avatar ?? this.avatar,
      preview: prview ?? preview,
      time: time ?? this.time,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}
