import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt         = Theme.of(context).textTheme;
    final cs         = Theme.of(context).colorScheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final goalsAsync      = ref.watch(goalsProvider);
    final recurringAsync  = ref.watch(recurringPaymentsProvider);
    final currency   = ref.watch(currencyProvider);
    final bgColor    = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: bgColor,
            title: Text('Goals & Planning', style: tt.headlineMedium),
          ),

          // ── Goals section ──────────────────────────────────────────────
          goalsAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (goalsList) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionHeader(
                    left: 'MY GOALS',
                    right: '${goalsList.length} goal${goalsList.length != 1 ? 's' : ''}',
                    icon: Icons.flag_rounded,
                    color: AppTheme.positive,
                    subtitle: 'Save towards your targets',
                    onAdd: () => _showAddGoal(context, ref),
                  ),
                  if (goalsList.isEmpty)
                    _EmptyCard(
                      emoji: '🎯',
                      message: 'No goals yet.\nTap Add to get started.',
                      cs: cs,
                      tt: tt,
                      isDark: isDark,
                    )
                  else
                    ...goalsList.asMap().entries.map((e) => _GoalCard(
                          goal: e.value,
                          colorIndex: e.key,
                          currency: currency,
                          cs: cs,
                          tt: tt,
                          isDark: isDark,
                          onContribute: () =>
                              _showContribute(context, ref, e.value),
                          onEdit: () =>
                              _showEditGoal(context, ref, e.value),
                          onDelete: () =>
                              _confirmDeleteGoal(context, ref, e.value),
                        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, duration: 350.ms)),
                ]),
              ),
            ),
          ),

          // ── Recurring payments section ────────────────────────────────
          recurringAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (list) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionHeader(
                    left: 'RECURRING',
                    right: '${list.length} active',
                    icon: Icons.repeat_rounded,
                    color: AppTheme.warning,
                    subtitle: 'Bills & subscriptions',
                    onAdd: () => _showAddRecurring(context, ref),
                  ),
                  if (list.isEmpty)
                    _EmptyCard(
                      emoji: '�',
                      message:
                          'No recurring payments.\nTap Add to set up a subscription or bill.',
                      cs: cs,
                      tt: tt,
                      isDark: isDark,
                    )
                  else
                    ...list.map((r) => _RecurringCard(
                          rec: r,
                          currency: currency,
                          cs: cs,
                          tt: tt,
                          isDark: isDark,
                          onDelete: () => ref
                              .read(databaseProvider)
                              .deleteRecurringPayment(r.id),
                          onEdit: () =>
                              _showEditRecurring(context, ref, r),
                        ).animate().fadeIn(duration: 300.ms)),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

    );
  }

  // ── Dialogs / sheets ──────────────────────────────────────────────────────

  Future<void> _showAddGoal(BuildContext context, WidgetRef ref) async {
    final nameCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();
    final sipCtrl    = TextEditingController();
    String emoji     = '🎯';
    DateTime deadline = DateTime.now().add(const Duration(days: 90));
    bool sipEnabled  = false;
    int sipDay       = 1;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const emojiOptions = [
      '🎯','🏖️','🚗','🏠','✈️','💍','🎓','💻','📱','🎸',
      '🏋️','🌍','🎬','📚','🍜','🛍️','🏄','⛷️','🎮','💎',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: cs.outline, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('New Goal', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Emoji picker
              Text('Pick an emoji', style: tt.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: emojiOptions.map((e) => GestureDetector(
                    onTap: () => setSt(() => emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? cs.onSurface.withAlpha(200)
                            : cs.onSurface.withAlpha(12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Goal name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Target amount'),
                onChanged: (_) {
                  if (!sipEnabled) return;
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  final now = DateTime.now();
                  final months = ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(1, 9999);
                  if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                },
              ),
              const SizedBox(height: 12),

              // Deadline picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: deadline,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setSt(() => deadline = picked);
                    if (sipEnabled) {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      final now = DateTime.now();
                      final months = ((picked.year - now.year) * 12 + picked.month - now.month).clamp(1, 9999);
                      if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deadline', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      Row(children: [
                        Text(DateFormat('d MMM yyyy').format(deadline), style: tt.bodyMedium),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── SIP toggle ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sipEnabled
                      ? cs.onSurface.withAlpha(10)
                      : cs.onSurface.withAlpha(5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sipEnabled
                        ? cs.onSurface.withAlpha(60)
                        : cs.outline.withAlpha(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.autorenew_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly SIP',
                                  style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              Text('Auto-contribute every month',
                                  style: tt.bodySmall),
                            ],
                          ),
                        ),
                        Switch(
                          value: sipEnabled,
                          onChanged: (v) {
                            setSt(() => sipEnabled = v);
                            if (v) {
                              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                              final now = DateTime.now();
                              final months = ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(1, 9999);
                              if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                            }
                          },
                        ),
                      ],
                    ),
                    if (sipEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sipCtrl,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'))
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Monthly amount',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: DropdownButtonFormField<int>(
                              // ignore: deprecated_member_use
                              value: sipDay,
                              decoration: const InputDecoration(
                                  labelText: 'On day',
                                  isDense: true),
                              items: List.generate(
                                  28,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1}'))),
                              onChanged: (v) =>
                                  setSt(() => sipDay = v ?? 1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name   = nameCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || amount <= 0) return;
                    final sip = sipEnabled
                        ? double.tryParse(sipCtrl.text.trim())
                        : null;
                    await ref.read(databaseProvider).insertGoal(
                      GoalsCompanion.insert(
                        name: name,
                        emoji: Value(emoji),
                        targetAmount: amount,
                        deadline: deadline,
                        sipAmount: Value(sip),
                        sipDay: Value(sipDay),
                        accountId: Value(ref.read(selectedAccountProvider)),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContribute(BuildContext context, WidgetRef ref, Goal goal) async {
    final ctrl   = TextEditingController();
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('${goal.emoji}  ${goal.name}',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '${formatAmount(goal.savedAmount, ref.read(currencyProvider))} saved of '
              '${formatAmount(goal.targetAmount, ref.read(currencyProvider))}',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Amount to add'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(ctrl.text.trim()) ?? 0;
                  if (amount <= 0) return;
                  final db = ref.read(databaseProvider);
                  await db.contributeToGoal(goal.id, amount);
                  // Record as investment transaction (won't count against budgets)
                  await db.insertTransaction(TransactionsCompanion.insert(
                    uuid: const Uuid().v4(),
                    amount: amount,
                    category: 'Investments',
                    description: 'Contribution – ${goal.name}',
                    date: DateTime.now(),
                    accountId: Value(goal.accountId),
                    txnType: const Value('investment'),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Add Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final nameCtrl   = TextEditingController(text: goal.name);
    final amountCtrl = TextEditingController(
        text: goal.targetAmount.toStringAsFixed(0));
    final sipCtrl   = TextEditingController(
        text: goal.sipAmount != null ? goal.sipAmount!.toStringAsFixed(0) : '');
    String emoji     = goal.emoji;
    DateTime deadline = goal.deadline;
    bool sipEnabled  = goal.sipAmount != null && goal.sipAmount! > 0;
    int sipDay       = goal.sipDay;
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    const emojiOptions = [
      '🎯','🏖️','🚗','🏠','✈️','💍','🎓','💻','📱','🎸',
      '🏋️','🌍','🎬','📚','🍜','🛍️','🏄','⛷️','🎮','💎',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
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
                const SizedBox(height: 16),
                Text('Edit Goal',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: emojiOptions.map((e) => GestureDetector(
                      onTap: () => setSt(() => emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? cs.onSurface.withAlpha(200)
                              : cs.onSurface.withAlpha(12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Goal name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Target amount'),
                  onChanged: (_) {
                    if (!sipEnabled) return;
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    final now = DateTime.now();
                    final months = ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(1, 9999);
                    if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setSt(() => deadline = picked);
                      if (sipEnabled) {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                        final now = DateTime.now();
                        final months = ((picked.year - now.year) * 12 + picked.month - now.month).clamp(1, 9999);
                        if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Deadline',
                            style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant)),
                        Row(children: [
                          Text(DateFormat('d MMM yyyy').format(deadline),
                              style: tt.bodyMedium),
                          const SizedBox(width: 8),
                          Icon(Icons.calendar_today_outlined,
                              size: 16, color: cs.onSurfaceVariant),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // SIP toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sipEnabled
                        ? cs.onSurface.withAlpha(10)
                        : cs.onSurface.withAlpha(5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sipEnabled
                          ? cs.onSurface.withAlpha(60)
                          : cs.outline.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.autorenew_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly SIP',
                                  style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              Text('Auto-contribute every month',
                                  style: tt.bodySmall),
                            ],
                          ),
                        ),
                        Switch(
                          value: sipEnabled,
                          onChanged: (v) {
                            setSt(() => sipEnabled = v);
                            if (v) {
                              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                              final now = DateTime.now();
                              final months = ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(1, 9999);
                              if (amt > 0) sipCtrl.text = (amt / months).ceil().toString();
                            }
                          },
                        ),
                      ]),
                      if (sipEnabled) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: sipCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'))
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Monthly amount',
                                  isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: DropdownButtonFormField<int>(
                              // ignore: deprecated_member_use
                              value: sipDay,
                              decoration: const InputDecoration(
                                  labelText: 'On day', isDense: true),
                              items: List.generate(
                                  28,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1}'))),
                              onChanged: (v) =>
                                  setSt(() => sipDay = v ?? 1),
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name   = nameCtrl.text.trim();
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (name.isEmpty || amount <= 0) return;
                      final sip = sipEnabled
                          ? double.tryParse(sipCtrl.text.trim())
                          : null;
                      await ref.read(databaseProvider).updateGoal(
                        goal.id,
                        GoalsCompanion(
                          name: Value(name),
                          emoji: Value(emoji),
                          targetAmount: Value(amount),
                          deadline: Value(deadline),
                          sipAmount: Value(sip),
                          sipDay: Value(sipDay),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(databaseProvider).deleteGoal(goal.id);
    }
  }

  Future<void> _showAddRecurring(BuildContext context, WidgetRef ref) async {
    final labelCtrl   = TextEditingController();
    final amountCtrl  = TextEditingController();
    String? category;
    String frequency  = 'monthly';
    int dayOfMonth    = 1;
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
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
              Text('Add Recurring Payment',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Label (e.g. Netflix, Rent)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration:
                    const InputDecoration(labelText: 'Amount per period'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: category,
                decoration:
                    const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text('${categoryEmoji(c)}  $c')))
                    .toList(),
                onChanged: (v) => setSt(() => category = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: frequency,
                decoration:
                    const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(
                      value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                      value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => frequency = v);
                },
              ),
              if (frequency == 'monthly') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: dayOfMonth,
                  decoration:
                      const InputDecoration(labelText: 'Day of month'),
                  items: List.generate(
                      28,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text('Day ${i + 1}'))),
                  onChanged: (v) {
                    if (v != null) setSt(() => dayOfMonth = v);
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final label  = labelCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    final cat    = category;
                    if (label.isEmpty || amount <= 0 || cat == null) return;
                    final now = DateTime.now();
                    final nextDue = frequency == 'monthly'
                        ? DateTime(now.year, now.month, dayOfMonth.clamp(1, 28))
                        : now;
                    await ref
                        .read(databaseProvider)
                        .insertRecurringPayment(
                          RecurringPaymentsCompanion.insert(
                            label: label,
                            category: cat,
                            amount: amount,
                            frequency: frequency,
                            dayOfMonth: Value(
                                frequency == 'monthly' ? dayOfMonth : null),
                            nextDueDate: nextDue.isAfter(now)
                                ? nextDue
                                : DateTime(now.year, now.month + 1, dayOfMonth.clamp(1, 28)),
                            accountId: Value(
                                ref.read(selectedAccountProvider)),
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Add Recurring'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditRecurring(
      BuildContext context, WidgetRef ref, RecurringPayment rec) async {
    final labelCtrl  = TextEditingController(text: rec.label);
    final amountCtrl = TextEditingController(text: rec.amount.toStringAsFixed(2));
    String category  = rec.category;
    String frequency = rec.frequency;
    int dayOfMonth   = rec.dayOfMonth ?? rec.nextDueDate.day;
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF11111F) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
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
              Text('Edit Recurring Payment',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(labelText: 'Amount per period'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text('${categoryEmoji(c)}  $c')))
                    .toList(),
                onChanged: (v) { if (v != null) setSt(() => category = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'daily',   child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly',  child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly',  child: Text('Yearly')),
                ],
                onChanged: (v) { if (v != null) setSt(() => frequency = v); },
              ),
              if (frequency == 'monthly') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: dayOfMonth.clamp(1, 28),
                  decoration: const InputDecoration(labelText: 'Day of month'),
                  items: List.generate(28,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text('Day ${i + 1}'))),
                  onChanged: (v) { if (v != null) setSt(() => dayOfMonth = v); },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final label  = labelCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (label.isEmpty || amount <= 0) return;
                    final now = DateTime.now();
                    final nextDue = frequency == 'monthly'
                        ? (() {
                            final d = dayOfMonth.clamp(1, 28);
                            final candidate = DateTime(now.year, now.month, d);
                            return candidate.isAfter(now)
                                ? candidate
                                : DateTime(now.year, now.month + 1, d);
                          })()
                        : rec.nextDueDate;
                    await ref.read(databaseProvider).updateRecurringPayment(
                      rec.id,
                      RecurringPaymentsCompanion(
                        label:      Value(label),
                        category:   Value(category),
                        amount:     Value(amount),
                        frequency:  Value(frequency),
                        dayOfMonth: Value(frequency == 'monthly' ? dayOfMonth : null),
                        nextDueDate: Value(nextDue),
                      ),
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

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String left;
  final String right;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.left,
    required this.right,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 18 : 12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    left,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (right.isNotEmpty)
              Text(
                right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: color),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Goal card ──────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final int colorIndex;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onContribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.colorIndex,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onContribute,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Category color only for the emoji chip; all card chrome uses goal-blue.
    final chipColor = AppTheme.categoryColors[colorIndex % AppTheme.categoryColors.length];
    const goalBlue  = Color(0xFF4D8FE8);
    final progress = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pct      = (progress * 100).round();
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;
    final isDone   = goal.savedAmount >= goal.targetAmount;
    final isOverdue = daysLeft < 0 && !isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goalBlue.withAlpha(80), width: 1),
        boxShadow: isDark
            ? [BoxShadow(color: goalBlue.withAlpha(30), blurRadius: 18, offset: const Offset(0, 4))]
            : [BoxShadow(color: goalBlue.withAlpha(25), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: chipColor.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(goal.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        isOverdue
                            ? '${daysLeft.abs()} days overdue'
                            : isDone
                                ? '🎉 Goal achieved!'
                                : '$daysLeft days left',
                        style: tt.labelSmall?.copyWith(
                          color: isOverdue
                              ? AppTheme.negative
                              : isDone
                                  ? AppTheme.positive
                                  : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arc progress indicator
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(52, 52),
                        painter: _ArcPainter(
                          progress: progress,
                          color: isDone ? AppTheme.positive : goalBlue,
                          trackColor: cs.onSurface.withAlpha(12),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDone ? AppTheme.positive : goalBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Amount info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAmount(goal.savedAmount, currency),
                      style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900, color: goalBlue),
                    ),
                    Text(
                      'of ${formatAmount(goal.targetAmount, currency)}',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
                Text(
                  DateFormat('MMM yyyy').format(goal.deadline),
                  style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: cs.onSurface.withAlpha(12),
                valueColor: AlwaysStoppedAnimation(
                    isDone ? AppTheme.positive : goalBlue),
                minHeight: 8,
              ),
            ),

            // SIP badge ─ fixed blue, properly spaced below progress bar
            if (goal.sipAmount != null && goal.sipAmount! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A6B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF4D8FE8), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.autorenew_rounded,
                        size: 13, color: Color(0xFF6EB5FF)),
                    const SizedBox(width: 4),
                    Text(
                      'Auto ${formatAmount(goal.sipAmount!, currency)} on day ${goal.sipDay}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6EB5FF)),
                    ),
                  ]),
                ),
              ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onContribute,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Contribute'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: goalBlue.withAlpha(120)),
                      foregroundColor: goalBlue,
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined,
                      color: cs.onSurfaceVariant, size: 19),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit goal',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: cs.onSurfaceVariant, size: 19),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete goal',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arc progress painter ───────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 5.0;
    const startAngle  = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Budget card ────────────────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  final RecurringPayment rec;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RecurringCard({
    required this.rec,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColors[categoryIndex(rec.category)];
    final emoji = categoryEmoji(rec.category);
    final dueStr =
        DateFormat('d MMM').format(rec.nextDueDate);
    final freqLabel = rec.frequency[0].toUpperCase() +
        rec.frequency.substring(1);

    return Dismissible(
      key: Key('rec-${rec.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.negative.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: AppTheme.negative, size: 22),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withAlpha(20), shape: BoxShape.circle),
              child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.label,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('$freqLabel · Next: $dueStr',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              formatAmount(rec.amount, currency),
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_outlined,
                  size: 18, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty card ─────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String emoji;
  final String message;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;

  const _EmptyCard(
      {required this.emoji,
      required this.message,
      required this.cs,
      required this.tt,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: Center(
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(message,
                  style: tt.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
