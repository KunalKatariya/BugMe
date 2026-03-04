import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final tt          = Theme.of(context).textTheme;
    final cs          = Theme.of(context).colorScheme;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final txnsAsync   = ref.watch(transactionsProvider);
    final currency    = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
            title: Text('Transactions', style: tt.headlineMedium),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Chip(
                    label: 'All',
                    emoji: '🗂️',
                    selected: _filterCategory == null,
                    cs: cs,
                    onTap: () => setState(() => _filterCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: cat,
                          emoji: categoryEmoji(cat),
                          selected: _filterCategory == cat,
                          cs: cs,
                          onTap: () => setState(() => _filterCategory = cat),
                        ),
                      )),
                ],
              ),
            ),
          ),

          txnsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e'))),
            data: (txns) {
              // Goal SIP contributions are savings transfers, not spending —
              // hide them from this list entirely.
              final visible = txns.where((t) => t.txnType != 'investment').toList();
              final filtered = _filterCategory == null
                  ? visible
                  : visible.where((t) => t.category == _filterCategory).toList();

      if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56, color: cs.onSurfaceVariant.withAlpha(80)),
                        const SizedBox(height: 12),
                        Text('No transactions',
                            style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Tap the mic to add your first entry',
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }

              // Group by date
              final Map<String, List<Transaction>> byDate = {};
              for (final t in filtered) {
                final key = DateFormat('yyyy-MM-dd').format(t.date);
                byDate.putIfAbsent(key, () => []).add(t);
              }
              final sortedKeys = byDate.keys.toList()
                ..sort((a, b) => b.compareTo(a));
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final yesterday = DateFormat('yyyy-MM-dd')
                  .format(DateTime.now().subtract(const Duration(days: 1)));

              String label(String k) {
                if (k == today) return 'TODAY';
                if (k == yesterday) return 'YESTERDAY';
                return DateFormat('d MMMM').format(DateTime.parse(k)).toUpperCase();
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final key   = sortedKeys[idx];
                      final group = byDate[key]!;
                      return _TxnGroup(
                        label: label(key),
                        txns: group,
                        currency: currency,
                        isDark: isDark,
                        cs: cs,
                        tt: tt,
                        onDelete: (t) => _delete(context, t),                        onEdit: (t) => _edit(context, t),                      );
                    },
                    childCount: sortedKeys.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Transaction t) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(t.description),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(databaseProvider).deleteTransaction(t.id);
    }
  }

  Future<void> _edit(BuildContext context, Transaction t) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountCtrl =
        TextEditingController(text: t.amount.toStringAsFixed(0));
    final descCtrl = TextEditingController(text: t.description);
    String category = t.category;
    DateTime date = t.date;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
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
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Edit Transaction',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categories.contains(category) ? category : 'Other',
                decoration:
                    const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text('${categoryEmoji(c)}  $c')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSt(() => date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      border: Border.all(color: cs.outline),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      Row(children: [
                        Text(DateFormat('d MMM yyyy').format(date),
                            style: tt.bodyMedium),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountCtrl.text.trim()) ?? 0;
                    final desc = descCtrl.text.trim();
                    if (amount <= 0 || desc.isEmpty) return;
                    await ref.read(databaseProvider).updateTransaction(
                          t.copyWith(
                              amount: amount,
                              description: desc,
                              category: category,
                              date: date),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transaction type badge helper ─────────────────────────────────────────

/// Returns a subtitle widget showing a coloured category pill plus, for
/// non-expense transactions, an additional type badge.
Widget _txnSubtitle(Transaction t, TextTheme tt, ColorScheme cs, Color catColor) {
  final isInvestment = t.txnType == 'investment';
  final isRecurring  = t.txnType == 'recurring';
  final typeBadgeColor = isInvestment
      ? const Color(0xFF4CAF50)
      : isRecurring
          ? const Color(0xFF42A5F5)
          : null;
  final typeBadgeLabel = isInvestment
      ? '📈 Investment'
      : isRecurring
          ? '🔄 Auto-pay'
          : null;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: catColor.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: catColor.withAlpha(80), width: 0.8),
        ),
        child: Text(
          t.category,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: catColor,
            letterSpacing: 0.1,
          ),
        ),
      ),
      if (typeBadgeColor != null) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: typeBadgeColor.withAlpha(28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: typeBadgeColor.withAlpha(100), width: 0.8),
          ),
          child: Text(
            typeBadgeLabel!,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: typeBadgeColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    ],
  );
}

// ── Filter chip ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.onSurface
              : cs.onSurface.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : cs.onSurface.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? cs.surface : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction group ──────────────────────────────────────────────────────

class _TxnGroup extends StatelessWidget {
  final String label;
  final List<Transaction> txns;
  final AppCurrency currency;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final void Function(Transaction) onDelete;
  final void Function(Transaction) onEdit;

  const _TxnGroup({
    required this.label,
    required this.txns,
    required this.currency,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child:
              Text(label, style: tt.labelLarge?.copyWith(letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline, width: isDark ? 0.5 : 1),
            boxShadow: isDark ? null : [
              BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: txns.asMap().entries.map((e) {
                final t       = e.value;
                final isFirst = e.key == 0;
                final color   = AppTheme
                    .categoryColors[categoryIndex(t.category)];
                final emoji   = categoryEmoji(t.category);

                return Column(children: [
                  if (!isFirst)
                    Divider(height: 1, indent: 72, endIndent: 16, color: cs.outline),
                  Dismissible(
                    key: Key(t.uuid),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppTheme.negative.withAlpha(20),
                      child: Icon(Icons.delete_outline_rounded,
                          color: AppTheme.negative, size: 22),
                    ),
                    confirmDismiss: (_) async {
                      onDelete(t);
                      return false;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: color, width: 3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        onLongPress: () => onEdit(t),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(22),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        title: Text(
                          t.description,
                          style: tt.bodyLarge?.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: _txnSubtitle(t, tt, cs, color),
                        trailing: Text(
                        '-${formatAmount(t.amount, currency)}',
                        style: TextStyle(
                            color: t.txnType == 'investment'
                                ? const Color(0xFF4CAF50)
                                : t.txnType == 'recurring'
                                    ? const Color(0xFF42A5F5)
                                    : cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
