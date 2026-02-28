import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const double _expandedHeight = 510.0;

  late final ScrollController _scroll;
  double _collapseRatio = 0.0; // 0 = fully expanded, 1 = fully collapsed
  int    _slideDir      = 1;   // 1 = forward (next), -1 = backward (prev)

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(userProfileProvider.notifier).load();
      if (mounted) {
        final acct = ref.read(selectedAccountProvider);
        ref.read(monthlyIncomeProvider.notifier).load(acct);
      }
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final topPad  = MediaQuery.of(context).padding.top;
    final maxEx   = _expandedHeight - kToolbarHeight - topPad;
    final ratio   = (_scroll.hasClients ? _scroll.offset : 0.0) / maxEx;
    final clamped = ratio.clamp(0.0, 1.0);
    if ((clamped - _collapseRatio).abs() > 0.005) {
      setState(() => _collapseRatio = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month       = ref.watch(selectedMonthProvider);
    final spend       = ref.watch(spendPerCategoryProvider);
    final allocAsync  = ref.watch(budgetAllocationsProvider);
    final txnsAsync   = ref.watch(transactionsProvider);
    final dailyAsync  = ref.watch(dailySpendProvider);
    final currency    = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final selectedId  = ref.watch(selectedAccountProvider);
    final accounts    = accountsAsync.valueOrNull ?? [];
    final activeAcct  = accounts.where((a) => a.id == selectedId).isNotEmpty
        ? accounts.firstWhere((a) => a.id == selectedId)
        : null;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final cs          = Theme.of(context).colorScheme;
    final tt          = Theme.of(context).textTheme;
    final monthLabel  = DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    final totalSpend  = spend.values.fold(0.0, (a, b) => a + b);
    final totalOutflow = ref.watch(totalMonthlyOutflowProvider);

    // ── Committed amounts (recurring configs + active SIPs) ───────────────
    // Mirror budget_screen committed calculation so the hero reflects the
    // full planned outflow even when auto-payments haven't been processed yet.
    final recurrings  = ref.watch(recurringPaymentsProvider).valueOrNull ?? [];
    final goals       = ref.watch(goalsProvider).valueOrNull ?? [];
    double monthlyEquiv(RecurringPayment r) {
      switch (r.frequency) {
        case 'daily':  return r.amount * 30;
        case 'weekly': return r.amount * 4.33;
        case 'yearly': return r.amount / 12;
        default:       return r.amount;
      }
    }
    final totalRecurring = recurrings.fold<double>(0, (s, r) => s + monthlyEquiv(r));
    final totalSIPs      = goals
        .where((g) => (g.sipAmount ?? 0) > 0 && g.savedAmount < g.targetAmount)
        .fold<double>(0, (s, g) => s + g.sipAmount!);
    final totalCommitted = totalRecurring + totalSIPs;
    final now          = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // Only boost with committed for the current month — past months have
    // fully-processed transactions so totalOutflow is already accurate.
    final displayedOutflow = month == currentMonth
        ? max(totalOutflow, totalSpend + totalCommitted)
        : totalOutflow;
    final totalBudget = allocAsync.valueOrNull
        ?.fold(0.0, (s, a) => s + a.allocatedAmount) ?? 0.0;
    final incomeMap   = ref.watch(monthlyIncomeProvider);
    final income      = incomeMap[selectedId] ?? 0.0;
    final dailySpend  = dailyAsync.valueOrNull ?? {};
    final profile     = ref.watch(userProfileProvider);
    final expandRatio = 1.0 - _collapseRatio;
    final isMonthEnded = month.compareTo(currentMonth) < 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Animated hero ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: _expandedHeight,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
            surfaceTintColor: Colors.transparent,
            // compact title row shown only when collapsed
            title: AnimatedOpacity(
              opacity: _collapseRatio > 0.85 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Row(
                children: [
                  Text(monthLabel,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  _MonthArrow(
                      icon: Icons.chevron_left,
                      onTap: () => _shiftMonth(ref, month, -1)),
                  _MonthArrow(
                      icon: Icons.chevron_right,
                      onTap: () => _shiftMonth(ref, month, 1)),
                ],
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              stretchModes: const [StretchMode.zoomBackground],
              background: _HeroBackground(
                expandRatio: expandRatio,
                totalSpend: totalSpend,
                totalOutflow: displayedOutflow,
                totalBudget: totalBudget,
                income: income,
                currency: currency,
                monthLabel: monthLabel,
                month: month,
                dailySpend: dailySpend,
                accounts: accounts,
                activeAccount: activeAcct,
                onPrev: () => _shiftMonth(ref, month, -1),
                onNext: () => _shiftMonth(ref, month, 1),
                onAccountTap: accounts.length > 1
                    ? () => _showAccountSwitcher(context, ref, accounts, selectedId)
                    : null,
                userName: profile.name,
                userAvatar: profile.avatar,
                slideDir: _slideDir,
              ),
            ),
          ),

          // ── White card body ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Budget summary card ───────────────────────────────
                  if (totalBudget > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _BudgetSummaryCard(
                        spent: totalSpend,
                        budget: totalBudget,
                        currency: currency,
                        cs: cs,
                        tt: tt,
                        isDark: isDark,
                      ).animate().fadeIn(duration: 350.ms),
                    ),

                  // ── Month-end report ──────────────────────────────────
                  if (isMonthEnded && (income > 0 || displayedOutflow > 0))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _MonthEndReport(
                        income: income,
                        totalSpent: displayedOutflow,
                        spend: spend,
                        allocs: allocAsync.valueOrNull ?? [],
                        currency: currency,
                        monthLabel: monthLabel,
                        month: month,
                        cs: cs,
                        tt: tt,
                        isDark: isDark,
                      ).animate().fadeIn(duration: 400.ms),
                    ),

                  // ── Recent grouped by date (current month only) ───────
                  if (!isMonthEnded)
                    txnsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (txns) {
                        if (txns.isEmpty) {
                          return _EmptyHint(
                            icon: '💸',
                            message: 'No spending this month.\nTap the mic to add your first entry.',
                            cs: cs,
                            tt: tt,
                          );
                        }
                        return _GroupedTransactions(
                          txns: txns,
                          currency: currency,
                          cs: cs,
                          tt: tt,
                          isDark: isDark,
                        );
                      },
                    ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, String current, int delta) {
    _slideDir = delta; // set before Riverpod rebuild so animation direction is correct
    final parts = current.split('-');
    var year = int.parse(parts[0]);
    var mon  = int.parse(parts[1]) + delta;
    if (mon > 12) { mon = 1; year++; }
    else if (mon < 1) { mon = 12; year--; }
    ref.read(selectedMonthProvider.notifier).state =
        '$year-${mon.toString().padLeft(2, '0')}';
  }

  void _showAccountSwitcher(BuildContext context, WidgetRef ref,
      List<Account> accounts, int selectedId) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding:
            const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline,
                      borderRadius:
                          BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Switch Account',
                style: tt.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...accounts.map((acc) {
              final isActive = acc.id == selectedId;
              final curr = currencyByCode(acc.currencyCode);
              return ListTile(
                leading: Text(acc.emoji,
                    style: const TextStyle(fontSize: 24)),
                title: Text(acc.name,
                    style: tt.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle:
                    Text(curr.name, style: tt.bodySmall),
                trailing: isActive
                    ? Icon(Icons.check_circle_rounded,
                        color: cs.onSurface, size: 20)
                    : null,
                onTap: isActive
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await ref
                            .read(selectedAccountProvider.notifier)
                            .switchAccount(acc.id);
                        await ref
                            .read(currencyProvider.notifier)
                            .setCurrency(currencyByCode(acc.currencyCode));
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Animated hero background ───────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  final double expandRatio; // 0 = collapsed, 1 = fully expanded
  final double totalSpend;   // expense-only, for budget badge comparison
  final double totalOutflow; // all types, shown as the hero number
  final double totalBudget;
  final double income;
  final AppCurrency currency;
  final String monthLabel;
  final String month;
  final Map<int, double> dailySpend;
  final List<Account> accounts;
  final Account? activeAccount;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onAccountTap;
  final String userName;
  final String userAvatar;
  final int slideDir;

  const _HeroBackground({
    required this.expandRatio,
    required this.totalSpend,
    required this.totalOutflow,
    required this.totalBudget,
    required this.income,
    required this.currency,
    required this.monthLabel,
    required this.month,
    required this.dailySpend,
    required this.accounts,
    required this.activeAccount,
    required this.onPrev,
    required this.onNext,
    this.onAccountTap,
    this.userName = 'You',
    this.userAvatar = '__logo__',
    this.slideDir = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Amount morphs: left-aligned small → centered huge
    final amountSize = 34.0 + 22.0 * expandRatio;
    final amountAlign = Alignment.lerp(
        Alignment.centerLeft, Alignment.center, expandRatio * expandRatio)!;
    final labelOpacity = expandRatio.clamp(0.0, 1.0);
    final chartOpacity = ((expandRatio - 0.45) / 0.35).clamp(0.0, 1.0);
    final budgetOpacity = ((expandRatio - 0.3) / 0.4).clamp(0.0, 1.0);
    final navOpacity = ((expandRatio - 0.55) / 0.3).clamp(0.0, 1.0);

    final overBudget = totalBudget > 0 && totalSpend > totalBudget;
    final badgeColor = overBudget ? AppTheme.negative : AppTheme.positive;
    final incomeSet       = income > 0;
    final incomeRemaining = income - totalOutflow;
    final incomeOver      = incomeSet && totalOutflow > income;
    final incomeBadgeColor = incomeOver ? AppTheme.negative : AppTheme.positive;

    // ── Helper: profile section (top, dark solid bg) ──────────────────
    final profileRow = Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(35), width: 1.5),
          ),
          child: userAvatar == '__logo__'
              ? ClipOval(
                  child: Image.asset('assets/images/logo.png',
                      fit: BoxFit.cover, width: 44, height: 44))
              : Center(
                  child: Text(userAvatar,
                      style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hey, $userName 👋',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            Text(
              '${_weekdayLabel(DateTime.now())}, ${_dateLabel(DateTime.now())}',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        Container(
      // Profile section: slightly darker warm base so it reads as card top
      color: isDark ? const Color(0xFF0C0903) : const Color(0xFF081222),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile row ───────────────────────────────────────────
            // Sits right under the status bar — no wasted gap.
            Opacity(
              opacity: navOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: profileRow,
              ),
            ),

            // ── Spend section with rounded top corners (curves) ───────
            // This creates the same "section divider" visual as the white
            // card below: each section peeks out with rounded top corners.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1C1407),
                            Color(0xFF3A2B0E),
                            Color(0xFF4D3B18),
                            Color(0xFF2E2109),
                            Color(0xFF181106),
                          ],
                          stops: [0.0, 0.25, 0.5, 0.72, 1.0],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E3050), Color(0xFF0C1A2E)],
                        ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        child: CustomPaint(painter: _HeroDecoPainter()),
                      ),
                    ),
                    Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Account switcher pill (multi-account only) ─
                      if (onAccountTap != null)
                        Opacity(
                          opacity: navOpacity,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: onAccountTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(activeAccount?.emoji ?? '🏦',
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 5),
                                    Text(
                                      activeAccount?.name ?? '',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 13,
                                        color: Colors.white54),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Month nav row ────────────────────────────────
                      Opacity(
                        opacity: navOpacity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(monthLabel,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Row(children: [
                              _MonthArrow(icon: Icons.chevron_left, onTap: onPrev),
                              _MonthArrow(icon: Icons.chevron_right, onTap: onNext),
                            ]),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── Month-keyed block (slides in/out on nav) ──────
                      Column(
                        key: ValueKey(month),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── "Total spent" label ─────────────────────────
                          Opacity(
                            opacity: labelOpacity,
                            child: Align(
                              alignment: amountAlign,
                              child: const Text(
                                'TOTAL SPENT',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11,
                                    fontWeight: FontWeight.w600, letterSpacing: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // ── Big amount (animated counter) ────────────────
                          Align(
                            alignment: amountAlign,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: totalOutflow),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (_, val, __) => Text(
                                formatAmount(val, currency),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: amountSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                ),
                              ),
                            ),
                          ),

                          // ── Budget / Income badge pill ───────────────────
                          if (incomeSet || totalBudget > 0)
                            Opacity(
                              opacity: budgetOpacity,
                              child: Align(
                                alignment: amountAlign,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (incomeSet)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: incomeBadgeColor.withAlpha(28),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: incomeBadgeColor.withAlpha(90),
                                                width: 1),
                                          ),
                                          child: Text(
                                            incomeOver
                                                ? '${formatAmount(totalOutflow - income, currency)} over income'
                                                : '${formatAmount(incomeRemaining, currency)} of ${formatAmount(income, currency)} left',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: incomeBadgeColor),
                                          ),
                                        ),
                                      if (!incomeSet && totalBudget > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withAlpha(28),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: badgeColor.withAlpha(90),
                                                width: 1),
                                          ),
                                          child: Text(
                                            overBudget
                                                ? 'Over budget by ${formatAmount(totalSpend - totalBudget, currency)}'
                                                : '${formatAmount(totalBudget - totalSpend, currency)} left of ${formatAmount(totalBudget, currency)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: badgeColor),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // ── Day-wise spending chart ──────────────────────
                          Opacity(
                            opacity: chartOpacity,
                            child: SizedBox(
                              height: 130 * expandRatio,
                              child: _DailySpendChart(
                                  dailySpend: dailySpend, month: month),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ).animate()
                          .fadeIn(duration: 280.ms, curve: Curves.easeOut)
                          .slideX(
                              begin: slideDir * 0.08,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic),
                    ],
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
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
            ),
          ),
        ),
      ],
    );
  }

  static String _weekdayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  static String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Hero decorative painter ────────────────────────────────────────────────────

class _HeroDecoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;

    // ── Large overlapping circles bleeding off top-right ─────────────────────
    stroke.color = const Color(0x22FFFFFF);
    canvas.drawCircle(
      Offset(size.width * 1.05, -size.height * 0.05),
      size.height * 0.72,
      stroke,
    );

    stroke.color = const Color(0x16FFFFFF);
    canvas.drawCircle(
      Offset(size.width * 0.85, -size.height * 0.12),
      size.height * 0.68,
      stroke,
    );

    // ── Soft glow at intersection ─────────────────────────────────────────────
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.05),
      size.height * 0.42,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0x09FFFFFF),
    );

    // ── Accent arc bottom-left for balance ───────────────────────────────────
    stroke.color = const Color(0x10FFFFFF);
    canvas.drawCircle(
      Offset(-size.width * 0.06, size.height * 1.05),
      size.height * 0.55,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Day-wise spending bar chart ──────────────────────────────────────────

String _fmtChartAmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 10000)  return '${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}


class _DailySpendChart extends StatelessWidget {
  final Map<int, double> dailySpend;
  final String month;

  const _DailySpendChart({required this.dailySpend, required this.month});

  @override
  Widget build(BuildContext context) {
    final year        = int.parse(month.split('-')[0]);
    final mon         = int.parse(month.split('-')[1]);
    final daysInMonth = DateUtils.getDaysInMonth(year, mon);
    final now         = DateTime.now();
    final isCurrentMonth = year == now.year && mon == now.month;
    final todayDay    = isCurrentMonth ? now.day : -1;

    final isDark      = Theme.of(context).brightness == Brightness.dark;

    // Compute max for y-axis
    double maxSpend = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final v = dailySpend[d] ?? 0.0;
      if (v > maxSpend) maxSpend = v;
    }
    final effectiveMax = maxSpend > 0 ? maxSpend * 1.3 : 500.0;
    final yInterval   = (effectiveMax / 4).ceilToDouble();

    const barAccent = Color(0xFFDDDDDD);
    const barDim   = Color(0x20FFFFFF);
    const todayCol = Color(0xFFFFD580);

    final groups = List.generate(daysInMonth, (i) {
      final day    = i + 1;
      final amount = dailySpend[day] ?? 0.0;
      final isToday = day == todayDay;
      final color = isToday
          ? todayCol
          : amount > 0
              ? barAccent
              : barDim;
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: amount > 0 ? amount : 0,
            color: color,
            width: daysInMonth >= 31 ? 5.5 : 6.5,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
        showingTooltipIndicators: [],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              const Text(
                'DAY-WISE SPENDING',
                style: TextStyle(
                    color: Colors.white38, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              if (isCurrentMonth) ...[  
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: todayCol, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('today', style: TextStyle(color: Colors.white30, fontSize: 9)),
              ],
            ],
          ),
        ),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: effectiveMax,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E1E1E),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tooltipMargin: 6,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    'Day ${group.x}',
                    const TextStyle(
                        color: Colors.white54, fontSize: 9,
                        fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(
                        text: '\n${_fmtChartAmt(rod.toY)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: yInterval,
                    getTitlesWidget: (val, meta) {
                      if (val == 0 || val > effectiveMax) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _fmtChartAmt(val),
                          style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 8,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (val, meta) {
                      final d = val.toInt();
                      // show 1, every 5th, and last day
                      if (d != 1 && d % 5 != 0 && d != daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '$d',
                        style: TextStyle(
                            color: d == todayDay
                                ? const Color(0xFFFFD580)
                                : Colors.white30,
                            fontSize: 8,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                drawHorizontalLine: true,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0x18FFFFFF), strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              barGroups: groups,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Month arrow button ─────────────────────────────────────────────────────

class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      );
}

// ── Budget summary card ────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final double spent;
  final double budget;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const _BudgetSummaryCard({
    required this.spent,
    required this.budget,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress  = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final remaining = budget - spent;
    final exceeded  = spent > budget;
    final barColor  = exceeded ? AppTheme.negative : AppTheme.positive;
    final pct       = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A1A), const Color(0xFF141414)]
              : [const Color(0xFFF0F0F0), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDFDFDF),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MONTHLY BUDGET', style: tt.labelLarge?.copyWith(letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                backgroundColor: cs.onSurface.withAlpha(12),
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatAmount(spent, currency),
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text('spent of ${formatAmount(budget, currency)}', style: tt.bodySmall),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  exceeded
                      ? formatAmount(spent - budget, currency)
                      : formatAmount(remaining, currency),
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: exceeded ? AppTheme.negative : AppTheme.positive),
                ),
                Text(exceeded ? 'over budget' : 'remaining', style: tt.bodySmall),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date-grouped transactions ──────────────────────────────────────────────

class _GroupedTransactions extends StatelessWidget {
  final List txns;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const _GroupedTransactions({
    required this.txns,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) return const SizedBox.shrink();

    // Group by date (day only)
    final Map<String, List> byDate = {};
    for (final t in txns) {
      final key = DateFormat('yyyy-MM-dd').format(t.date as DateTime);
      byDate.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    String dateLabel(String key) {
      if (key == today) return 'TODAY';
      if (key == yesterday) return 'YESTERDAY';
      return DateFormat('d MMMM').format(DateTime.parse(key)).toUpperCase();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Divider(color: cs.outline, height: 24),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text('RECENT', style: tt.labelLarge),
        ),
        ...sortedKeys.map((key) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141414) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: cs.outline.withAlpha(50), width: 1),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: _DateGroup(
                  label: dateLabel(key),
                  txns: byDate[key]!,
                  currency: currency,
                  cs: cs,
                  tt: tt,
                  isDark: isDark,
                ),
              ),
            )),
      ],
    );
  }
}

class _DateGroup extends StatelessWidget {
  final String label;
  final List txns;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const _DateGroup({
    required this.label,
    required this.txns,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(label,
              style: tt.labelLarge?.copyWith(letterSpacing: 1.2)),
        ),
        ...txns.asMap().entries.map((e) {
          final t       = e.value;
          final isFirst = e.key == 0;
          final isLast  = e.key == txns.length - 1;
          final color   = AppTheme
              .categoryColors[categoryIndex(t.category as String)];
          final emoji   = categoryEmoji(t.category as String);

          return Column(children: [
            if (!isFirst)
              Divider(height: 1, indent: 72, endIndent: 20, color: cs.outline),
            ListTile(
              contentPadding:
                  const EdgeInsets.fromLTRB(20, 4, 20, 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                t.description as String,
                style: tt.bodyLarge?.copyWith(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                t.category as String,
                style: tt.bodySmall,
              ),
              trailing: Text(
                '-${formatAmount(t.amount as double, currency)}',
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
            if (isLast) const SizedBox(height: 4),
          ]);
        }),
      ],
    );
  }
}

// ── Month-end report ───────────────────────────────────────────────────────

class _MonthEndReport extends StatelessWidget {
  final double income;
  final double totalSpent;
  final Map<String, double> spend;
  final List<BudgetAllocation> allocs;
  final AppCurrency currency;
  final String monthLabel;
  final String month;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const _MonthEndReport({
    required this.income,
    required this.totalSpent,
    required this.spend,
    required this.allocs,
    required this.currency,
    required this.monthLabel,
    required this.month,
    required this.cs,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncome = income > 0;
    final saved     = hasIncome ? income - totalSpent : 0.0;
    final isOver    = saved < -0.01;
    final savedPct  = hasIncome && income > 0
        ? ((saved.abs() / income) * 100).clamp(0, 100)
        : 0.0;

    // Avg daily spend
    final parts       = month.split('-');
    final daysInMonth = DateUtils.getDaysInMonth(
        int.parse(parts[0]), int.parse(parts[1]));
    final avgDaily = totalSpent > 0 ? totalSpent / daysInMonth : 0.0;

    // Top categories by spend (up to 3)
    final topCats  = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSlice = topCats.take(3).toList();

    // Budget performance
    int overCount = 0, trackCount = 0;
    for (final a in allocs) {
      if ((spend[a.category] ?? 0) > a.allocatedAmount) overCount++;
      else trackCount++;
    }

    // Find most overspent / most under-budget category
    String? worstCat;
    double worstExcess = 0;
    String? bestCat;
    double bestSaving = 0;
    for (final a in allocs) {
      final s = spend[a.category] ?? 0;
      final excess  = s - a.allocatedAmount;
      final saving  = a.allocatedAmount - s;
      if (excess  > worstExcess) { worstExcess = excess;  worstCat = a.category; }
      if (saving  > bestSaving && s > 0) { bestSaving = saving; bestCat = a.category; }
    }

    // Specific, actionable tip
    String tip;
    if (!hasIncome) {
      final dayPart = avgDaily > 0
          ? 'You averaged ${formatAmount(avgDaily, currency)}/day. '
          : '';
      tip = '${dayPart}Set your monthly income in the Budget tab to unlock full savings insights.';
    } else if (isOver) {
      if (worstCat != null) {
        final target = (spend[worstCat]! * 0.8).ceilToDouble();
        tip = '$worstCat pushed you over by ${formatAmount(worstExcess, currency)}. '
              'Capping it at ${formatAmount(target, currency)} next month would bring you back on track.';
      } else {
        final cutPerDay = (saved.abs() / daysInMonth).ceilToDouble();
        tip = 'Overspent by ${formatAmount(saved.abs(), currency)} — about '
              '${formatAmount(cutPerDay, currency)}/day over limit. Trimming small daily expenses compounds fast.';
      }
    } else if (savedPct >= 20) {
      if (bestCat != null) {
        tip = 'Saving ${savedPct.toStringAsFixed(0)}% is excellent! '
              '$bestCat had ${formatAmount(bestSaving, currency)} left over — consider directing that toward a goal.';
      } else {
        tip = 'Saving ${savedPct.toStringAsFixed(0)}% puts you above the 20% target. '
              'Averaged ${formatAmount(avgDaily, currency)}/day — keep that discipline going!';
      }
    } else {
      final gap        = (income * 0.2) - saved;
      final trimPerDay = (gap / daysInMonth).ceilToDouble();
      tip = '${savedPct.toStringAsFixed(0)}% saved (target: 20%). '
            'Trimming just ${formatAmount(trimPerDay, currency)}/day more would hit the goal'
            '${worstCat != null ? ' — start with $worstCat.' : '.'}';
    }

    final accentColor = isOver ? AppTheme.negative : AppTheme.positive;
    final headerEmoji = isOver ? '😬' : savedPct >= 20 ? '🎉' : '👍';
    final headerText  = isOver
        ? 'Over budget by ${formatAmount(saved.abs(), currency)}'
        : hasIncome
            ? 'Saved ${formatAmount(saved, currency)} (${savedPct.toStringAsFixed(0)}%)'
            : 'Spent ${formatAmount(totalSpent, currency)} this month';

    return Container(
      decoration: BoxDecoration(
        color: accentColor.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(50), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Text(headerEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$monthLabel Wrap-up',
                          style: tt.labelSmall?.copyWith(
                              letterSpacing: 1.1,
                              color: accentColor.withAlpha(180),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(headerText,
                          style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Stats pills ────────────────────────────────────────────────
          if (hasIncome)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _StatPill(
                    label: 'Income',
                    value: formatAmount(income, currency),
                    color: cs.onSurfaceVariant,
                    tt: tt,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: 'Spent',
                    value: formatAmount(totalSpent, currency),
                    color: isOver ? AppTheme.negative : cs.onSurface,
                    tt: tt,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: isOver ? 'Over' : 'Saved',
                    value: formatAmount(saved.abs(), currency),
                    color: accentColor,
                    tt: tt,
                    highlight: true,
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),

          // ── Spending breakdown ──────────────────────────────────────────
          if (topSlice.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPENDING BREAKDOWN',
                    style: tt.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant.withAlpha(160)),
                  ),
                  if (avgDaily > 0)
                    Text(
                      'avg ${formatAmount(avgDaily, currency)}/day',
                      style: tt.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant.withAlpha(160)),
                    ),
                ],
              ),
            ),
            ...topSlice.map((e) {
              final pct   = totalSpent > 0 ? (e.value / totalSpent).clamp(0.0, 1.0) : 0.0;
              double? allocAmt;
              for (final a in allocs) {
                if (a.category == e.key) { allocAmt = a.allocatedAmount; break; }
              }
              final isOverCat = allocAmt != null && e.value > allocAmt;
              final barColor  = isOverCat ? AppTheme.negative : accentColor;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Text(categoryEmoji(e.key),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: tt.bodySmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatAmount(e.value, currency),
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isOverCat
                                      ? AppTheme.negative
                                      : cs.onSurface),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${(pct * 100).round()}%',
                                textAlign: TextAlign.right,
                                style: tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: cs.onSurfaceVariant
                                        .withAlpha(160)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: cs.onSurface.withAlpha(10),
                              valueColor: AlwaysStoppedAnimation(
                                  barColor.withAlpha(180)),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Budget performance chips ────────────────────────────────────
          if (allocs.isNotEmpty && (overCount > 0 || trackCount > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (trackCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.positive.withAlpha(14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.positive.withAlpha(50), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_rounded,
                            size: 10, color: AppTheme.positive),
                        const SizedBox(width: 4),
                        Text('$trackCount on track',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.positive)),
                      ]),
                    ),
                  if (overCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.negative.withAlpha(14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.negative.withAlpha(50), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 10, color: AppTheme.negative),
                        const SizedBox(width: 4),
                        Text('$overCount over budget',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.negative)),
                      ]),
                    ),
                ],
              ),
            ),

          // ── Tip ────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, topSlice.isEmpty && !hasIncome ? 12 : 4, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tip,
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  final TextTheme tt;
  final bool highlight;
  final Color? accentColor;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.tt,
    this.highlight = false,
    this.accentColor,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: highlight
            ? BoxDecoration(
                color: accentColor!.withAlpha(14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor!.withAlpha(50)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: tt.labelSmall
                    ?.copyWith(color: color.withAlpha(160), fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String icon, label, value;
  final TextTheme tt;
  final ColorScheme cs;
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tt,
    required this.cs,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          Divider(height: 1, thickness: 0.5, color: cs.outline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Text(label,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
                const Spacer(),
                Text(value,
                    style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty hint ─────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String icon;
  final String message;
  final ColorScheme cs;
  final TextTheme tt;
  const _EmptyHint(
      {required this.icon,
      required this.message,
      required this.cs,
      required this.tt});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(message,
                  style: tt.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

/// Shared category icon helper (kept for compatibility with other screens).
IconData categoryIcon(String category) => switch (category) {
      'Groceries'       => Icons.shopping_basket_outlined,
      'Restaurants'     => Icons.restaurant_outlined,
      'Coffee & Drinks' => Icons.local_cafe_outlined,
      'Transport'       => Icons.directions_car_outlined,
      'Entertainment'   => Icons.movie_outlined,
      'Shopping'        => Icons.shopping_bag_outlined,
      'Travel'          => Icons.flight_outlined,
      'Health & Fitness'=> Icons.fitness_center_outlined,
      'Utilities & Bills'=> Icons.bolt_outlined,
      'Subscriptions'   => Icons.subscriptions_outlined,
      'Education'       => Icons.school_outlined,
      'Personal Care'   => Icons.face_outlined,
      'Rent & Housing'  => Icons.home_outlined,
      'Investments'     => Icons.trending_up_outlined,
      _                 => Icons.attach_money_outlined,
    };
