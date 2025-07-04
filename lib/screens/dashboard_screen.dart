import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_function.dart';
import '../models/nav_item.dart';
import '../models/message.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  var _selectedNavIndex = 0;
  late AnimationController _animationController;
  List<Message> messages = [
    Message(
      sender: "John Doe",
      avatar: "JD",
      preview: "Hey! Don't forget about our meeting tomorrow at 2 PM",
      time: "2m",
      isUnread: true,
    ),
    Message(
      sender: "Sarah Miller",
      avatar: "SM",
      preview: "The project update looks great! Let's discuss the next steps",
      time: "15m",
      isUnread: true,
    ),
    Message(
      sender: "Mike Johnson",
      avatar: "MJ",
      preview: "Thanks for sharing the documents. I'll review them today",
      time: "1h",
      isUnread: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
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
                              _buildMessagesSection(),
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

  Widget _buildMessagesSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                child: const Text(
                  "3",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...messages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
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
                          index * 0.1,
                          0.6 + (index * 0.1),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    );
                return SlideTransition(
                  position: slideAnimation,
                  child: _buildMessageItem(message, index),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          messages[index] = message.copyWith(isUnread: false);
        });
        _showSnackBar("Opening message from ${message.sender}");
      },
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
            itemBuilder: (context, index){
              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child){
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        0.2 + (index * 0.1),
                        0.8 + (index * 0.1),
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
          )
        ],
      ),
    );
  }

  Widget _buildFunctionCard(AppFunction function){
    return GestureDetector(
      onTap: () => _navigateToFunction(function),

    );
  }

  Widget _buildBottomNavigation() {
    final navItems = [
      NavItem(icon: "🏠", label: "Home", badge: null),
      NavItem(icon: "💬", label: "Messages", badge: "5"),
      NavItem(icon: "📊", label: "Analytics", badge: null),
      NavItem(icon: "⚙️", label: "Settings", badge: null),
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
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    )
                    : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  MainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Text(
                          item.icon,
                          style: TextStyle(
                            fontSize: 20,
                            color: isActive ? Colors.white : Color.black54,
                          ),
                        ),
                        if(item.badge != null)
                          Position(
                            right: -5,
                            top: -5,
                          ),
                      ],
                    ),
                  ],
                ),  
              ),
          ),
        }
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
    _showSnackBar("Navigating to ${function.title}...");
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
