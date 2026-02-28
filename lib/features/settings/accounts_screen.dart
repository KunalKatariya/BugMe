import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt           = Theme.of(context).textTheme;
    final cs           = Theme.of(context).colorScheme;
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsProvider);
    final selectedId   = ref.watch(selectedAccountProvider);
    final bgColor      = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: bgColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: cs.onSurface, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Accounts', style: tt.headlineMedium),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Each account has its own currency, budget, and goals.\nSwitch accounts to manage them separately.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  accountsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, _) =>
                        Text('Error loading accounts', style: tt.bodySmall),
                    data: (accs) => Column(
                      children: [
                        ...accs.asMap().entries.map((e) {
                          final acc     = e.value;
                          final isActive = acc.id == selectedId;
                          final currency = currencyByCode(acc.currencyCode);
                          return _AccountCard(
                            account: acc,
                            currency: currency,
                            isActive: isActive,
                            isDark: isDark,
                            cs: cs,
                            tt: tt,
                            canDelete: accs.length > 1,
                            onTap: () => _selectAccount(context, ref, acc),
                            onDelete: () =>
                                _confirmDelete(context, ref, acc, selectedId),
                            onEdit: () =>
                                _showEditAccount(context, ref, acc),
                          ).animate().fadeIn(duration: 300.ms).slideY(
                                begin: 0.05, duration: 350.ms);
                        }),
                        const SizedBox(height: 12),
                        _AddAccountButton(
                          isDark: isDark,
                          cs: cs,
                          tt: tt,
                          onTap: () => _showAddAccount(context, ref),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectAccount(
      BuildContext context, WidgetRef ref, Account acc) async {
    await ref.read(selectedAccountProvider.notifier).switchAccount(acc.id);
    // Sync currency to the new account's currency
    await ref
        .read(currencyProvider.notifier)
        .setCurrency(currencyByCode(acc.currencyCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Switched to ${acc.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Account acc,
      int selectedId) async {
    if (acc.id == selectedId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cannot delete the active account'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${acc.name}?'),
        content: const Text(
            'This will permanently delete the account and all its transactions, budget, and goals.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(databaseProvider).deleteAccount(acc.id);
    }
  }

  Future<void> _showAddAccount(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    String emoji   = '🏦';
    String selectedCurrCode = ref.read(currencyProvider).code;
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('New Account', style: tt.titleLarge),
              const SizedBox(height: 20),

              // Emoji picker row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickEmoji(ctx, setS,
                        (e) => emoji = e),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 26))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Currency selector
              Text('Currency', style: tt.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: supportedCurrencies.map((c) {
                  final isSel = c.code == selectedCurrCode;
                  return GestureDetector(
                    onTap: () => setS(() => selectedCurrCode = c.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? cs.onSurface
                            : cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSel
                                ? cs.onSurface
                                : cs.outline),
                      ),
                      child: Text(
                        '${c.symbol}  ${c.code}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? (isDark ? Colors.black : Colors.white)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertAccount(
                      AccountsCompanion.insert(
                        name: name,
                        emoji: Value(emoji),
                        currencyCode: Value(selectedCurrCode),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditAccount(
      BuildContext context, WidgetRef ref, Account acc) async {
    final nameCtrl = TextEditingController(text: acc.name);
    String emoji   = acc.emoji;
    String selectedCurrCode = acc.currencyCode;
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
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
              const SizedBox(height: 16),
              Text('Edit Account', style: tt.titleLarge),
              const SizedBox(height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickEmoji(
                        ctx, setS, (e) => emoji = e),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 26))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Currency', style: tt.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: supportedCurrencies.map((c) {
                  final isSel = c.code == selectedCurrCode;
                  return GestureDetector(
                    onTap: () => setS(() => selectedCurrCode = c.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? cs.onSurface
                            : cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isSel ? cs.onSurface : cs.outline),
                      ),
                      child: Text(
                        '${c.symbol}  ${c.code}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? (isDark ? Colors.black : Colors.white)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).updateAccount(
                          acc.id,
                          AccountsCompanion(
                            name: Value(name),
                            emoji: Value(emoji),
                            currencyCode: Value(selectedCurrCode),
                          ),
                        );
                    // Sync currency if this is the active account
                    if (ref.read(selectedAccountProvider) == acc.id) {
                      await ref
                          .read(currencyProvider.notifier)
                          .setCurrency(currencyByCode(selectedCurrCode));
                    }
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

  void _pickEmoji(
      BuildContext ctx, StateSetter setS, void Function(String) onPick) {
    const emojis = [
      '🏦', '💰', '💳', '💴', '💵', '💶', '💷', '🪙',
      '🏧', '💹', '📊', '🏪', '🏠', '✈️', '🌏', '🌸',
    ];
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Pick an emoji'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () {
                      setS(() => onPick(e));
                      Navigator.pop(ctx);
                    },
                    child: Text(e,
                        style: const TextStyle(fontSize: 28)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Account card ───────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Account account;
  final AppCurrency currency;
  final bool isActive;
  final bool canDelete;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.account,
    required this.currency,
    required this.isActive,
    required this.canDelete,
    required this.isDark,
    required this.cs,
    required this.tt,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4D8FE8).withAlpha(180)
                : cs.outline,
            width: isActive ? 1.5 : 0.8,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: const Color(0xFF4D8FE8).withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4D8FE8).withAlpha(20)
                    : cs.onSurface.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(account.emoji,
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name,
                      style: tt.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${currency.name} (${currency.symbol})',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4D8FE8).withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF4D8FE8).withAlpha(80)),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6EB5FF))),
              ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 19, color: cs.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
            ),
            if (!isActive && canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 19, color: cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Add account button ─────────────────────────────────────────────────────

class _AddAccountButton extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  const _AddAccountButton(
      {required this.isDark,
      required this.cs,
      required this.tt,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.onSurface.withAlpha(6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: cs.onSurface.withAlpha(20), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Add Account',
                  style: tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
}
