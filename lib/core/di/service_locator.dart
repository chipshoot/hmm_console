import 'package:get_it/get_it.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static void setupDependencies() {
    // Register your services here
    // Example: _getIt.registerSingleton<YourService>(YourService());
  }

  static T get<T extends Object>() {
    return _getIt<T>();
  }

  static bool isRegistered<T extends Object>() {
    return _getIt.isRegistered<T>();
  }
}