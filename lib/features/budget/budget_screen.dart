import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../goals/goals_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BudgetScreen — zero-based income-first budget planner
// ─────────────────────────────────────────────────────────────────────────────

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});
  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final acct = ref.read(selectedAccountProvider);
        ref.read(monthlyIncomeProvider.notifier).load(acct);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final tt          = Theme.of(context).textTheme;
    final cs          = Theme.of(context).colorScheme;
    final month       = ref.watch(selectedMonthProvider);
    final accountId   = ref.watch(selectedAccountProvider);
    final incomeMap   = ref.watch(monthlyIncomeProvider);
    final income      = incomeMap[accountId] ?? 0.0;
    final allocAsync  = ref.watch(budgetAllocationsProvider);
    final recurAsync  = ref.watch(recurringPaymentsProvider);
    final goalsAsync  = ref.watch(goalsProvider);
    final spend       = ref.watch(spendPerCategoryProvider);
    final currency    = ref.watch(currencyProvider);
    final bgColor     = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);
    final monthLabel  = DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));

    final recurrings  = recurAsync.valueOrNull ?? [];
    final goals       = goalsAsync.valueOrNull ?? [];
    final allocs      = allocAsync.valueOrNull ?? [];

    // ── Committed calculations ────────────────────────────────────────────
    double monthlyEquiv(RecurringPayment r) {
      switch (r.frequency) {
        case 'daily':  return r.amount * 30;
        case 'weekly': return r.amount * 4.33;
        case 'yearly': return r.amount / 12;
        default:       return r.amount;
      }
    }

    final totalRecurring = recurrings.fold<double>(0, (s, r) => s + monthlyEquiv(r));
    final activeSIPs     = goals.where(
        (g) => (g.sipAmount ?? 0) > 0 && g.savedAmount < g.targetAmount).toList();
    final totalSIPs      = activeSIPs.fold<double>(0, (s, g) => s + g.sipAmount!);
    final totalCommitted = totalRecurring + totalSIPs;
    final totalVariable  = allocs.fold<double>(0, (s, a) => s + a.allocatedAmount);
    final unallocated    = income > 0 ? income - totalCommitted - totalVariable : 0.0;
    final isOver         = unallocated < -0.01;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                pinned: false,
                toolbarHeight: 64,
                backgroundColor: bgColor,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget Plan', style: tt.headlineMedium),
                    Text(monthLabel, style: tt.bodySmall),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Copy last month',
                    icon: const Icon(Icons.copy_all_outlined, size: 20),
                    onPressed: () => _copyLastMonth(context, month, accountId),
                  ),
                ],
              ),

              // ── Income card ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _IncomeCard(
                    income: income,
                    committed: totalCommitted,
                    variable: totalVariable,
                    unallocated: unallocated,
                    isOver: isOver,
                    currency: currency,
                    isDark: isDark,
                    cs: cs,
                    tt: tt,
                    onEditIncome: () => _editIncome(context, income, accountId),
                  ),
                ).animate().fadeIn(duration: 350.ms),
              ),

              // ── Committed section ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'COMMITTED',
                        subtitle: 'Auto-deducted from income',
                        value: formatAmount(totalCommitted, currency),
                        icon: Icons.lock_outline_rounded,
                        color: const Color(0xFF42A5F5),
                        tt: tt,
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _CommittedCard(
                        recurrings: recurrings,
                        activeSIPs: activeSIPs,
                        goals: goals,
                        monthlyEquiv: monthlyEquiv,
                        currency: currency,
                        isDark: isDark,
                        cs: cs,
                        tt: tt,
                        onManage: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GoalsScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GoalsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : const Color(0xFFEAEAEA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: cs.outline, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  size: 16, color: cs.onSurface),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Manage Goals & Recurring Payments',
                                  style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded,
                                  color: cs.onSurfaceVariant, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
              ),

              // ── Variable spending section ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'VARIABLE SPENDING',
                        subtitle: 'Your discretionary budgets',
                        value: formatAmount(totalVariable, currency),
                        icon: Icons.tune_rounded,
                        color: cs.primary,
                        tt: tt,
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      if (allocs.isEmpty)
                        _EmptyVariableCard(
                          isDark: isDark,
                          cs: cs,
                          tt: tt,
                          onAdd: () => _addCategory(context, month, accountId, currency),
                        )
                      else
                        _VariableCard(
                          allocs: allocs,
                          spend: spend,
                          currency: currency,
                          isDark: isDark,
                          cs: cs,
                          tt: tt,
                          onEdit:   (a) => _editAllocation(context, a, spend[a.category] ?? 0, currency),
                          onDelete: (a) => ref.read(databaseProvider).deleteAllocation(a.id),
                        ),
                      const SizedBox(height: 12),
                      _AddCategoryButton(
                        isDark: isDark,
                        cs: cs,
                        tt: tt,
                        onTap: () => _addCategory(context, month, accountId, currency),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),

          // ── Sticky wallet bar ────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _WalletBar(
              income: income,
              unallocated: unallocated,
              isOver: isOver,
              currency: currency,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _editIncome(
      BuildContext context, double current, int accountId) async {
    final ctrl = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Monthly Income',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Set your take-home salary or total monthly income.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(ref.read(currencyProvider).symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.onSurface,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final val = double.tryParse(ctrl.text.trim()) ?? 0;
                  if (val > 0) {
                    await ref.read(monthlyIncomeProvider.notifier)
                        .set(accountId, val);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCategory(
      BuildContext context, String month, int accountId, AppCurrency currency) async {
    String category = categories.first;
    final amtCtrl   = TextEditingController();
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allocs = ref.read(budgetAllocationsProvider).valueOrNull ?? [];
    final used   = allocs.map((a) => a.category).toSet();
    final available = categories.where((c) => !used.contains(c)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All categories have been added.')));
      return;
    }
    category = available.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Add Budget Category',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: available
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${categoryEmoji(c)}  $c')))
                    .toList(),
                onChanged: (v) { if (v != null) setSt(() => category = v); },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amtCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters:
                    [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: 'Monthly limit',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(currency.symbol,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.onSurface,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(amtCtrl.text.trim()) ?? 0;
                    if (val <= 0) return;
                    await ref.read(databaseProvider).upsertAllocation(
                      BudgetAllocationsCompanion.insert(
                        month: month,
                        category: category,
                        allocatedAmount: val,
                        accountId: Value(accountId),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Add',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAllocation(BuildContext context, BudgetAllocation alloc,
      double spent, AppCurrency currency) async {
    final ctrl = TextEditingController(
        text: alloc.allocatedAmount.toStringAsFixed(0));
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = AppTheme.categoryColors[categoryIndex(alloc.category)];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(categoryEmoji(alloc.category),
                        style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alloc.category,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Spent: ${formatAmount(spent, currency)}',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters:
                  [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Monthly budget limit',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(currency.symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: AppTheme.negative.withAlpha(100)),
                    foregroundColor: AppTheme.negative,
                  ),
                  onPressed: () async {
                    await ref.read(databaseProvider).deleteAllocation(alloc.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Remove',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(ctrl.text.trim()) ?? 0;
                    if (val <= 0) return;
                    await ref.read(databaseProvider).upsertAllocation(
                      BudgetAllocationsCompanion.insert(
                        month: alloc.month,
                        category: alloc.category,
                        allocatedAmount: val,
                        accountId: Value(alloc.accountId),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLastMonth(
      BuildContext context, String month, int accountId) async {
    final parts = month.split('-');
    var y = int.parse(parts[0]);
    var m = int.parse(parts[1]) - 1;
    if (m < 1) { m = 12; y--; }
    final prev = '$y-${m.toString().padLeft(2, '0')}';
    await ref.read(databaseProvider)
        .carryForwardAllocations(prev, month, accountId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Budget copied from last month!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Income card
// ─────────────────────────────────────────────────────────────────────────────

class _IncomeCard extends StatelessWidget {
  final double income, committed, variable, unallocated;
  final bool isOver;
  final AppCurrency currency;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onEditIncome;

  const _IncomeCard({
    required this.income,
    required this.committed,
    required this.variable,
    required this.unallocated,
    required this.isOver,
    required this.currency,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    final unallocColor = isOver
        ? AppTheme.negative
        : unallocated < 1 && income > 0
            ? AppTheme.positive
            : cs.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Income row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MONTHLY INCOME',
                        style: tt.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    income > 0
                        ? Text(
                            formatAmount(income, currency),
                            style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5),
                          )
                        : GestureDetector(
                            onTap: onEditIncome,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: cs.primary.withAlpha(18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: cs.primary.withAlpha(80),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded,
                                      color: cs.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Set your income',
                                      style: tt.bodyMedium?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              if (income > 0)
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18,
                      color: cs.onSurfaceVariant),
                  onPressed: onEditIncome,
                  tooltip: 'Edit income',
                ),
            ],
          ),

          if (income > 0) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 16),

            // Committed row
            _AllocRow(
              label: '🔒  Committed',
              value: formatAmount(committed, currency),
              portion: income > 0 ? (committed / income).clamp(0, 1) : 0,
              color: const Color(0xFF42A5F5),
              tt: tt,
              cs: cs,
            ),
            const SizedBox(height: 10),

            // Variable row
            _AllocRow(
              label: '💳  Variable',
              value: formatAmount(variable, currency),
              portion: income > 0 ? (variable / income).clamp(0, 1) : 0,
              color: cs.primary,
              tt: tt,
              cs: cs,
            ),
            const SizedBox(height: 14),

            // Unallocated chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: unallocColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: unallocColor.withAlpha(80), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOver
                            ? Icons.warning_amber_rounded
                            : unallocated < 1 && income > 0
                                ? Icons.check_circle_rounded
                                : Icons.savings_outlined,
                        color: unallocColor, size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOver
                            ? '${formatAmount(unallocated.abs(), currency)} over budget'
                            : unallocated < 1 && income > 0
                                ? 'Fully allocated ✓'
                                : '${formatAmount(unallocated, currency)} left to allocate',
                        style: TextStyle(
                            color: unallocColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AllocRow extends StatelessWidget {
  final String label, value;
  final double portion;
  final Color color;
  final TextTheme tt;
  final ColorScheme cs;

  const _AllocRow({
    required this.label,
    required this.value,
    required this.portion,
    required this.color,
    required this.tt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                  Text(value,
                      style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: portion,
                  minHeight: 5,
                  backgroundColor: color.withAlpha(22),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, subtitle, value;
  final IconData icon;
  final Color color;
  final TextTheme tt;
  final ColorScheme cs;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.tt,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: tt.labelLarge?.copyWith(
                      letterSpacing: 1.0, fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Text(value,
            style: tt.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Committed card
// ─────────────────────────────────────────────────────────────────────────────

class _CommittedCard extends StatelessWidget {
  final List<RecurringPayment> recurrings;
  final List<Goal> activeSIPs;
  final List<Goal> goals;
  final double Function(RecurringPayment) monthlyEquiv;
  final AppCurrency currency;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onManage;

  const _CommittedCard({
    required this.recurrings,
    required this.activeSIPs,
    required this.goals,
    required this.monthlyEquiv,
    required this.currency,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = recurrings.isEmpty && activeSIPs.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No recurring payments or SIPs yet.\nAdd them in the Goals tab.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.55),
                  ),
                ),
              ]),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  ...recurrings.asMap().entries.map((e) {
                    final r     = e.value;
                    final amt   = monthlyEquiv(r);
                    final isFirst = e.key == 0;
                    return Column(children: [
                      if (!isFirst)
                        Divider(height: 1, thickness: 0.5, color: cs.outline),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5).withAlpha(18),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(categoryEmoji(r.category),
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(r.label,
                            style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          '${_freqLabel(r.frequency)} · ${r.category}',
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                        trailing: Text(
                          formatAmount(amt, currency),
                          style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ]);
                  }),
                  ...activeSIPs.asMap().entries.map((e) {
                    final g     = e.value;
                    final showDiv = recurrings.isNotEmpty || e.key > 0;
                    return Column(children: [
                      if (showDiv)
                        Divider(height: 1, thickness: 0.5, color: cs.outline),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF26A69A).withAlpha(18),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(g.emoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(g.name,
                            style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          'SIP · Monthly investment',
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                        trailing: Text(
                          formatAmount(g.sipAmount!, currency),
                          style: const TextStyle(
                              color: Color(0xFF26A69A),
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ]);
                  }),
                ],
              ),
            ),
    );
  }

  String _freqLabel(String freq) {
    switch (freq) {
      case 'daily':   return 'Daily ×30';
      case 'weekly':  return 'Weekly ×4.33';
      case 'yearly':  return 'Yearly ÷12';
      default:        return 'Monthly';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Variable spending card
// ─────────────────────────────────────────────────────────────────────────────

class _VariableCard extends StatelessWidget {
  final List<BudgetAllocation> allocs;
  final Map<String, double> spend;
  final AppCurrency currency;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final void Function(BudgetAllocation) onEdit;
  final void Function(BudgetAllocation) onDelete;

  const _VariableCard({
    required this.allocs,
    required this.spend,
    required this.currency,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: allocs.asMap().entries.map((e) {
            final i       = e.key;
            final a       = e.value;
            final spent   = spend[a.category] ?? 0.0;
            final ratio   = a.allocatedAmount > 0
                ? (spent / a.allocatedAmount).clamp(0.0, 1.0)
                : 0.0;
            final exceeded = spent > a.allocatedAmount && a.allocatedAmount > 0;
            final color   = exceeded
                ? AppTheme.negative
                : AppTheme.categoryColors[categoryIndex(a.category)];

            return Column(children: [
              if (i > 0)
                Divider(height: 1, thickness: 0.5, color: cs.outline),
              Dismissible(
                key: ValueKey(a.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppTheme.negative.withAlpha(20),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.negative, size: 22),
                ),
                confirmDismiss: (_) async {
                  onDelete(a);
                  return false;
                },
                child: GestureDetector(
                  onTap: () => onEdit(a),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(color: color, width: 3)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(categoryEmoji(a.category),
                                style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(a.category,
                                      style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  Row(children: [
                                    Text(
                                      formatAmount(spent, currency),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: exceeded
                                              ? AppTheme.negative
                                              : cs.onSurfaceVariant),
                                    ),
                                    Text(
                                      ' / ${formatAmount(a.allocatedAmount, currency)}',
                                      style: tt.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ]),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 5,
                                  backgroundColor: color.withAlpha(20),
                                  valueColor:
                                      AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_outlined,
                            size: 16, color: cs.onSurfaceVariant
                                .withAlpha(100)),
                      ],
                    ),
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyVariableCard extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onAdd;

  const _EmptyVariableCard({
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: Row(children: [
          const Text('💳', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No categories yet.\nTap here to add your first budget category.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.55),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  const _AddCategoryButton({
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cs.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.primary.withAlpha(60), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Text('Add Category',
                style: tt.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sticky wallet bar
// ─────────────────────────────────────────────────────────────────────────────

class _WalletBar extends StatelessWidget {
  final double income, unallocated;
  final bool isOver;
  final AppCurrency currency;
  final bool isDark;

  const _WalletBar({
    required this.income,
    required this.unallocated,
    required this.isOver,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final cs     = Theme.of(context).colorScheme;
    final color  = isOver
        ? AppTheme.negative
        : unallocated < 1 && income > 0
            ? AppTheme.positive
            : cs.primary;

    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      color: bgColor,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(60)),

          ),
          child: income == 0
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.savings_outlined, color: color, size: 16),
                    const SizedBox(width: 8),
                    Text('Set your monthly income to start planning',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      isOver
                          ? Icons.warning_amber_rounded
                          : unallocated < 1
                              ? Icons.check_circle_rounded
                              : Icons.account_balance_wallet_outlined,
                      color: color, size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOver
                                ? '${formatAmount(unallocated.abs(), currency)} over-allocated'
                                : unallocated < 1
                                    ? 'Budget fully allocated!'
                                    : '${formatAmount(unallocated, currency)} unallocated',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 15),
                          ),
                          Text(
                            '${formatAmount(income, currency)} total income',
                            style: tt.bodySmall
                                ?.copyWith(color: color.withAlpha(160)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${((unallocated / income) * 100).abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
