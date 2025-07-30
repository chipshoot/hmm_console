import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';
import '../../domain/providers/i_message_provider.dart';

class MessageViewModel extends ChangeNotifier {
  final IMessageProvider _messageProvider;
  final AnimationController animationController;

  List<Message> _messages = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<Message> get messages => _messages;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  MessageViewModel(this._messageProvider, this.animationController);

  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();

    try {
      _messages = await _messageProvider.getRecentMessages();
      _unreadCount = await _messageProvider.getUnreadCount();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markMessageAsRead(int index) async {
    if (index >= 0 && index < _messages.length) {
      final message = _messages[index];
      if (message.isUnread) {
        try {
          await _messageProvider.markMessageAsRead(message.id);
          _messages[index] = message.copyWith(isUnread: false);
          _unreadCount = await _messageProvider.getUnreadCount();
          notifyListeners();
        } catch (e) {
          // Handle error
        }
      }
    }
  }

  void onMessageTap(int index, BuildContext context) {
    markMessageAsRead(index);
    final message = _messages[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Opening message from ${message.sender}"),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Animation<Offset> getSlideAnimation(int index) {
    return Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(
          index * 0.1,
          0.6 + (index * 0.1),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}