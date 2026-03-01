import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/idp_token_service.dart';
import '../../../../domain/entities/app_function.dart';
import '../../../auth/data/models/current_user.dart';
import '../../../auth/providers/current_user_provider.dart';
import '../../../auth/usecases/signout_usecase.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
    });
    _restoreUserIfNeeded();
  }

  Future<void> _restoreUserIfNeeded() async {
    if (ref.read(currentUserProvider) != null) return;
    final claims = await ref.read(idpTokenServiceProvider).getStoredClaims();
    if (claims != null && mounted) {
      ref.read(currentUserProvider.notifier).setUser(
            CurrentUserDataModel(
              uid: claims['sub'] as String? ?? '',
              email: claims['email'] as String?,
              displayName: claims['name'] as String?,
              photoUrl: claims['picture'] as String?,
            ),
          );
    }
  }

  static final _allFunctions = [
    AppFunction(
      icon: "\u26FD",
      title: "Gas Log",
      description: "Track fuel consumption",
      route: "gas-log",
    ),
    AppFunction(
      icon: "\uD83C\uDF45",
      title: "Pomodoro",
      description: "Focus timer",
      route: "pomodoro",
    ),
    AppFunction(
      icon: "\uD83D\uDCB0",
      title: "Expenses",
      description: "Track spending",
      route: "expenses",
    ),
    AppFunction(
      icon: "\uD83D\uDCDD",
      title: "Notes",
      description: "Quick notes",
      route: "notes",
    ),
    AppFunction(
      icon: "\uD83C\uDF24\uFE0F",
      title: "Weather",
      description: "Current forecast",
      route: "weather",
    ),
    AppFunction(
      icon: "\uD83D\uDCC5",
      title: "Calendar",
      description: "Schedule events",
      route: "calendar",
    ),
  ];

  List<AppFunction> get _filteredFunctions {
    if (_searchQuery.isEmpty) return _allFunctions;
    final query = _searchQuery.toLowerCase();
    return _allFunctions
        .where(
          (f) =>
              f.title.toLowerCase().contains(query) ||
              f.description.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(user, colorScheme),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 584),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        _buildBrandText(colorScheme),
                        const SizedBox(height: 32),
                        _buildSearchBar(colorScheme),
                        const SizedBox(height: 40),
                        _buildShortcuts(colorScheme),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(CurrentUserDataModel? user, ColorScheme colorScheme) {
    final displayName = user?.displayName ?? user?.email?.split('@').first;
    final greeting = _getGreeting();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            displayName != null ? '$greeting, $displayName' : greeting,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'settings') {
                context.push('/settings');
              }
              if (value == 'sign_out') {
                ref.read(signOutUseCaseProvider).signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: _buildAvatar(user, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CurrentUserDataModel? user, ColorScheme colorScheme) {
    final photoUrl = user?.photoUrl;
    final name = user?.displayName ?? user?.email?.split('@').first;
    final initials = _getInitials(name);

    if (photoUrl != null) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, _) {},
        child: Text(initials, style: const TextStyle(fontSize: 14)),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBrandText(ColorScheme colorScheme) {
    return Text(
      'Hmm',
      style: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w400,
        color: colorScheme.primary,
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      onSubmitted: (value) {
        final filtered = _filteredFunctions;
        if (filtered.length == 1) {
          _navigateToFunction(filtered.first);
        }
      },
      decoration: InputDecoration(
        hintText: 'Search functions...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildShortcuts(ColorScheme colorScheme) {
    final functions = _filteredFunctions;

    if (functions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'No matching functions',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Wrap(
      spacing: 24,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: functions.map((f) => _buildShortcutItem(f, colorScheme)).toList(),
    );
  }

  Widget _buildShortcutItem(AppFunction function, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _navigateToFunction(function),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.secondaryContainer,
              child: Text(function.icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 8),
            Text(
              function.title,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  void _navigateToFunction(AppFunction function) {
    switch (function.route) {
      case 'gas-log':
        context.push('/automobiles');
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${function.title} coming soon...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
    }
  }
}
