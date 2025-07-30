import 'package:get_it/get_it.dart';
import '../../features/message_management/data/repositories/i_message_repository.dart';
import '../../features/message_management/data/repositories/local_message_repository.dart';
import '../../features/message_management/domain/providers/i_message_provider.dart';
import '../../features/message_management/domain/providers/message_provider.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static void setupDependencies() {
    // Register repositories
    _getIt.registerSingleton<IMessageRepository>(LocalMessageRepository());

    // Register providers
    _getIt.registerSingleton<IMessageProvider>(
      MessageProvider(_getIt<IMessageRepository>()),
    );
  }

  static T get<T extends Object>() {
    return _getIt<T>();
  }

  static bool isRegistered<T extends Object>() {
    return _getIt.isRegistered<T>();
  }
}
