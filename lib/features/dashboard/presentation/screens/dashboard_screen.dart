import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/app_function.dart';
import '../../../../domain/entities/nav_item.dart';
import '../../../message_management/data/providers/message_providers.dart';
import '../../../message_management/presentation/views/message_list_view.dart';
import '../../../message_management/presentation/viewmodels/message_view_model.dart';
import '../../../auth/usecases/signout_usecase.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  var _selectedNavIndex = 0;
  late AnimationController _animationController;
  late MessageViewModel _messageViewModel;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final messageProvider = ref.read(messageProviderProvider);
    _messageViewModel =
        MessageViewModel(messageProvider, _animationController);

    _animationController.forward();
    _messageViewModel.loadMessages();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.0),
                      topRight: Radius.circular(30.0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            children: [
                              ListenableBuilder(
                                listenable: _messageViewModel,
                                builder: (context, child) {
                                  return MessageListView(
                                    viewModel: _messageViewModel,
                                  );
                                },
                              ),
                              _buildFunctionGrid(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final timeFormat = DateFormat('EEEE, MMMM d, y . h:mm a');
    final greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Alex",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            timeFormat.format(now),
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionGrid() {
    final functions = [
      AppFunction(
        icon: "⛽",
        title: "Gas Log",
        description: "Track fuel consumption",
        route: "gas-log",
      ),
      AppFunction(
        icon: "🍅",
        title: "Pomodoro",
        description: "Focus timer",
        route: "pomodoro",
      ),
      AppFunction(
        icon: "💰",
        title: "Expenses",
        description: "Track spending",
        route: "expenses",
      ),
      AppFunction(
        icon: "📝",
        title: "Notes",
        description: "Quick notes",
        route: "notes",
      ),
      AppFunction(
        icon: "🌤️",
        title: "Weather",
        description: "Current forecast",
        route: "weather",
      ),
      AppFunction(
        icon: "📅",
        title: "Calendar",
        description: "Schedule events",
        route: "calendar",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              "Quick Access",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.1,
            ),
            itemCount: functions.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final slideAnimation =
                      Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            0.2 + (index * 0.05),
                            0.6 + (index * 0.05),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      );
                  return SlideTransition(
                    position: slideAnimation,
                    child: _buildFunctionCard(functions[index]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard(AppFunction function) {
    return GestureDetector(
      onTap: () => _navigateToFunction(function),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  function.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              function.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              function.description,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final navItems = [
      NavItem(icon: "🏠", label: "Home", badge: null),
      NavItem(icon: "💬", label: "Messages", badge: "5"),
      NavItem(icon: "📊", label: "Analytics", badge: null),
      NavItem(icon: "⚙️", label: "Sign Out", badge: null),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = _selectedNavIndex == index;

            return GestureDetector(
              onTap: () {
                if (index == 3) {
                  ref.read(signOutUseCaseProvider).signOut();
                  return;
                }
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Text(
                          item.icon,
                          style: TextStyle(
                            fontSize: 20,
                            color: isActive ? Colors.white : Colors.black54,
                          ),
                        ),
                        if (item.badge != null)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4757),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                item.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? Colors.white : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  void _navigateToFunction(AppFunction function) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Navigating to ${function.title}..."),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
