import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/goals/goals_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/voice/voice_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: BugMeApp()));
}

class BugMeApp extends ConsumerStatefulWidget {
  const BugMeApp({super.key});

  @override
  ConsumerState<BugMeApp> createState() => _BugMeAppState();
}

class _BugMeAppState extends ConsumerState<BugMeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.setAppGroupId('com.bugme.bugme');
    Future.microtask(() async {
      await ref.read(themeModeProvider.notifier).load();
      await ref.read(currencyProvider.notifier).load();
      await ref.read(geminiServiceProvider).init();
      final storedKey = await ref.read(geminiServiceProvider).getApiKey();
      if (storedKey != null && mounted) {
        ref.read(apiKeyProvider.notifier).state = storedKey;
      }
      // Load active account and sync its currency
      await ref.read(selectedAccountProvider.notifier).load();
      final accountId = ref.read(selectedAccountProvider);
      final account = await ref.read(databaseProvider).getAccount(accountId);
      if (account != null && mounted) {
        await ref
            .read(currencyProvider.notifier)
            .setCurrency(currencyByCode(account.currencyCode));
      }
      // Auto-process monthly SIP contributions for all goals
      await ref.read(databaseProvider).processSipContributions();
      // Auto-create transactions for overdue recurring payments
      await ref.read(databaseProvider).processRecurringPayments();
      // Refresh home-screen widget
      _updateWidget();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidget();
    }
  }

  /// Writes current month spend + account name to the home-screen widget.
  Future<void> _updateWidget() async {
    try {
      final db        = ref.read(databaseProvider);
      final accountId = ref.read(selectedAccountProvider);
      final account   = await db.getAccount(accountId);
      final now       = DateTime.now();
      final month     =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final spend     = await db.spendPerCategory(month, accountId);
      final total =
          spend.values.fold(0.0, (sum, v) => sum + v);
      final currency = ref.read(currencyProvider);
      final spendStr = '${currency.symbol}${total.toStringAsFixed(currency.decimalDigits)}';

      await HomeWidget.saveWidgetData<String>(
          'widget_monthly_spend', spendStr);
      await HomeWidget.saveWidgetData<String>(
          'widget_account_name', account?.name ?? 'Personal');
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.bugme.bugme.BugMeWidgetProvider',
      );
    } catch (_) {
      // Widget update is non-critical — ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'BugMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    DashboardScreen(),
    TransactionsScreen(),
    VoiceEntryScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);
    final navBg   = isDark ? const Color(0xFF111111) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(80)
                  : Colors.black.withAlpha(18),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,            label: 'Home',    index: 0, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.receipt_long_outlined,  activeIcon: Icons.receipt_long_rounded,    label: 'Txns',    index: 1, current: _currentIndex, onTap: _onTap),
                _NavItemCta(
                  index: 2,
                  current: _currentIndex,
                  isDark: isDark,
                  onTap: () => _onTap(2),
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    ref.read(autoStartRecordingProvider.notifier).state = true;
                    _onTap(2);
                  },
                ),
                _NavItem(icon: Icons.flag_outlined,          activeIcon: Icons.flag_rounded,            label: 'Goals',   index: 3, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.settings_outlined,      activeIcon: Icons.settings_rounded,        label: 'Settings',index: 4, current: _currentIndex, onTap: _onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(int i) => setState(() => _currentIndex = i);
}

// ── Regular nav item ───────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark
                        ? Colors.white.withAlpha(18)
                        : Colors.black.withAlpha(10))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Centre CTA button ──────────────────────────────────────────────────────

class _NavItemCta extends StatelessWidget {
  final int index;
  final int current;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NavItemCta({
    required this.index,
    required this.current,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    final cs       = Theme.of(context).colorScheme;

    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : cs.onSurface,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: cs.onSurface.withAlpha(isDark ? 60 : 50),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isDark ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
