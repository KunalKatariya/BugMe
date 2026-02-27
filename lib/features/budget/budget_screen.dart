import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt          = Theme.of(context).textTheme;
    final cs          = Theme.of(context).colorScheme;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final month       = ref.watch(selectedMonthProvider);
    final allocAsync  = ref.watch(budgetAllocationsProvider);
    final spend       = ref.watch(spendPerCategoryProvider);
    final currency    = ref.watch(currencyProvider);
    final monthLabel  =
        DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    final bgColor     = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: bgColor,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget', style: tt.headlineMedium),
                Text(monthLabel, style: tt.bodySmall),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () =>
                    _addDialog(context, ref, month, currency, cs, tt, isDark),
              ),
            ],
          ),
          allocAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e'))),
            data: (allocs) {
              if (allocs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('💰', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 14),
                      Text('No budgets for $monthLabel',
                          style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text('Tap + to set one', style: tt.bodySmall),
                    ]),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final a     = allocs[i];
                      final spent = spend[a.category] ?? 0.0;
                      final budget = a.allocatedAmount;
                      final exceeded = spent > budget;
                      final progress = budget > 0
                          ? (spent / budget).clamp(0.0, 1.0)
                          : 0.0;
                      final color = exceeded
                          ? AppTheme.negative
                          : AppTheme.categoryColors[categoryIndex(a.category)];
                      final emoji = categoryEmoji(a.category);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BudgetCard(
                          a: a,
                          spent: spent,
                          progress: progress,
                          exceeded: exceeded,
                          color: color,
                          emoji: emoji,
                          currency: currency,
                          isDark: isDark,
                          cs: cs,
                          tt: tt,
                          onDelete: () => ref
                              .read(databaseProvider)
                              .deleteAllocation(a.id),
                        ),
                      );
                    },
                    childCount: allocs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addDialog(
    BuildContext ctx,
    WidgetRef ref,
    String month,
    AppCurrency currency,
    ColorScheme cs,
    TextTheme tt,
    bool isDark,
  ) async {
    String? selCat = categories.first;
    final amtCtrl = TextEditingController();

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (shCtx, setSt) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(shCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Set Budget', style: tt.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selCat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${categoryEmoji(c)}  $c',
                              style: tt.bodyMedium)))
                      .toList(),
                  onChanged: (v) => setSt(() => selCat = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Amount (${currency.symbol})'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amt = double.tryParse(amtCtrl.text) ?? 0;
                      if (amt > 0 && selCat != null) {
                        ref.read(databaseProvider).upsertAllocation(
                              BudgetAllocationsCompanion.insert(
                                month: month,
                                category: selCat!,
                                allocatedAmount: amt,
                              ),
                            );
                        Navigator.pop(shCtx);
                      }
                    },
                    child: const Text('Save Budget'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Budget card ────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetAllocation a;
  final double spent;
  final double progress;
  final bool exceeded;
  final Color color;
  final String emoji;
  final AppCurrency currency;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.a,
    required this.spent,
    required this.progress,
    required this.exceeded,
    required this.color,
    required this.emoji,
    required this.currency,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.category,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (exceeded)
                      Text('Over budget',
                          style: tt.labelMedium?.copyWith(
                              color: AppTheme.negative,
                              letterSpacing: 0)),
                  ]),
                ]),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: cs.onSurfaceVariant),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,   // always 0.0–1.0, never null
                backgroundColor: cs.onSurface.withAlpha(12),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatAmount(spent, currency)} spent',
                  style: tt.bodySmall?.copyWith(
                      color: exceeded ? AppTheme.negative : null),
                ),
                Text('of ${formatAmount(a.allocatedAmount, currency)}',
                    style: tt.bodySmall),
              ],
            ),
          ],
        ),
      );
}
