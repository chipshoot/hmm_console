import 'package:flutter/material.dart';
import '../viewmodels/message_view_model.dart';
import 'message_item_view.dart';

class MessageListView extends StatelessWidget {
  final MessageViewModel viewModel;

  const MessageListView({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                " Recent Messages",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4757),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  viewModel.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...viewModel.messages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            return AnimatedBuilder(
              animation: viewModel.animationController,
              builder: (context, child) {
                final slideAnimation = viewModel.getSlideAnimation(index);
                return SlideTransition(
                  position: slideAnimation,
                  child: MessageItemView(
                    message: message,
                    index: index,
                    onTap: () => viewModel.onMessageTap(index, context),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}