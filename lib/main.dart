import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/budget/budget_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
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
      // Check onboarding state (must come before first frame)
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool('onboarding_done') ?? false;
      if (mounted) {
        ref.read(onboardingDoneProvider.notifier).state = onboarded;
      }
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
    final themeMode     = ref.watch(themeModeProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    return MaterialApp(
      title: 'BugMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: switch (onboardingDone) {
        null  => const _SplashScreen(),   // loading
        false => const OnboardingScreen(), // first launch
        true  => const _AppShell(),        // returning user
      },
    );
  }
}

// ── Splash (shown for ~50 ms while onboarding flag loads) ─────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Color(0xFF0A0A0A));
}

// ── App shell ─────────────────────────────────────────────────────────────

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
    BudgetScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Floating pill nav bar — sits above the bottom safe area.
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        onTap: _onTap,
        onMicLongPress: () {
          HapticFeedback.heavyImpact();
          ref.read(autoStartRecordingProvider.notifier).state = true;
          _onTap(2);
        },
      ),
    );
  }

  void _onTap(int i) => setState(() => _currentIndex = i);
}

// ── Floating nav bar container ─────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final void Function(int) onTap;
  final VoidCallback onMicLongPress;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    required this.onMicLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  // Dark: subtle white rim; Light: visible dark outline to lift pill off bg
                  color: isDark
                      ? Colors.white.withAlpha(28)
                      : Colors.black.withAlpha(16),
                  width: 1,
                ),
                // Glass tint + top-edge tube highlight in one gradient
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withAlpha(26),
                          Colors.white.withAlpha(12),
                          Colors.white.withAlpha(8),
                        ]
                      : [
                          // Cool blue-white frosted top
                          const Color(0xFFFFFFFF).withAlpha(240),
                          // Slight cool tint mid
                          const Color(0xFFF0F4FF).withAlpha(200),
                          // Deeper cool at bottom for depth
                          const Color(0xFFE6ECFA).withAlpha(185),
                        ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  // Main lift shadow
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha(70)
                        : Colors.black.withAlpha(28),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                  // Ambient glow
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha(30)
                        : Colors.black.withAlpha(10),
                    blurRadius: 48,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    index: 0,
                    current: currentIndex,
                    onTap: onTap,
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    index: 1,
                    current: currentIndex,
                    onTap: onTap,
                  ),
                  _NavItemCta(
                    index: 2,
                    current: currentIndex,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onTap(2);
                    },
                    onLongPress: onMicLongPress,
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    index: 3,
                    current: currentIndex,
                    onTap: onTap,
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    index: 4,
                    current: currentIndex,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Regular nav item ───────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    final cs       = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? cs.primary.withAlpha(22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? cs.primary : cs.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Centre CTA mic button ──────────────────────────────────────────────────

class _NavItemCta extends StatelessWidget {
  final int index;
  final int current;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NavItemCta({
    required this.index,
    required this.current,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    // White button in dark mode, near-black in light — sharp & premium.
    final ctaColor  = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final iconColor = isDark ? Colors.black : Colors.white;

    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: isActive ? 60 : 54,
            height: isActive ? 60 : 54,
            decoration: BoxDecoration(
              color: ctaColor,
              borderRadius: BorderRadius.circular(isActive ? 20 : 18),
              boxShadow: [
                BoxShadow(
                  color: ctaColor.withAlpha(isActive ? 70 : 40),
                  blurRadius: isActive ? 20 : 10,
                  spreadRadius: isActive ? 1 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: iconColor,
              size: isActive ? 28 : 24,
            ),
          ),
        ),
      ),
    );
  }
}
