import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'core/di/service_locator.dart';

void main() {
  // Initialize dependency injection
  ServiceLocator.setupDependencies();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DashboardScreen());
  }
}
