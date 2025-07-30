import 'service_locator.dart';
import '../../features/message_management/domain/providers/i_message_provider.dart';

/// Example usage of the Service Locator
///
/// This file demonstrates how to use the ServiceLocator to access
/// registered dependencies throughout your application.
class ServiceLocatorExample {
  /// Example of getting the message provider from anywhere in your app
  static Future<void> demonstrateUsage() async {
    // Get the message provider instance
    final messageProvider = ServiceLocator.get<IMessageProvider>();

    // Use the provider to get recent messages
    final messages = await messageProvider.getRecentMessages(limit: 5);
    print('Found ${messages.length} recent messages');

    // Get unread count
    final unreadCount = await messageProvider.getUnreadCount();
    print('You have $unreadCount unread messages');

    // Watch for real-time updates
    messageProvider.watchUnreadCount().listen((count) {
      print('Unread count updated: $count');
    });
  }

  /// Check if a service is registered
  static bool isMessageProviderRegistered() {
    return ServiceLocator.isRegistered<IMessageProvider>();
  }
}
