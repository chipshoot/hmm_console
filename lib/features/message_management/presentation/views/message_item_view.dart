import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';

class MessageItemView extends StatelessWidget {
  final Message message;
  final int index;
  final VoidCallback onTap;

  const MessageItemView({
    super.key,
    required this.message,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: message.isUnread
              ? const Color(0xFFE3F2FD)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(15),
          border: Border(
            left: BorderSide(
              color: message.isUnread
                  ? const Color(0xFF2196F3)
                  : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.avatar,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.sender,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message.preview,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message.time,
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}