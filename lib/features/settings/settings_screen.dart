import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/app_providers.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import 'export_report_screen.dart';
import 'personal_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt       = Theme.of(context).textTheme;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final currency  = ref.watch(currencyProvider);
    final apiKey    = ref.watch(apiKeyProvider);
    final profile   = ref.watch(userProfileProvider);
    final bgColor   = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: bgColor,
            title: Text('Settings', style: tt.headlineMedium),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Appearance ──────────────────────────
                  _Header('APPEARANCE'),
                  _Card(isDark: isDark, cs: cs, child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: cs.onSurface,
                    ),
                    title: Text('Theme', style: tt.bodyLarge),
                    subtitle: Text(
                        themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                        style: tt.bodySmall),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      activeThumbColor: Colors.white,
                      activeTrackColor: isDark
                          ? const Color(0xFF4A4A4A)
                          : const Color(0xFF1A1A1A),
                      inactiveThumbColor: cs.onSurfaceVariant,
                      inactiveTrackColor: cs.outline,
                    ),
                  )),

                  const SizedBox(height: 20),

                  // ── Accounts ─────────────────────────────
                  _Header('ACCOUNTS'),
                  // Personal
                  _Card(isDark: isDark, cs: cs, child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        shape: BoxShape.circle,
                      ),
                        child: profile.avatar == '__logo__'
                          ? ClipOval(
                              child: Image.asset('assets/images/logo.png',
                                  fit: BoxFit.cover, width: 36, height: 36))
                          : Center(
                              child: Text(profile.avatar,
                                  style: const TextStyle(fontSize: 18))),
                    ),
                    title: Text('Personal', style: tt.bodyLarge),
                    subtitle: Text(profile.name, style: tt.bodySmall),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonalScreen()),
                      );
                      // Reload profile on return
                      if (context.mounted) {
                        ref.read(userProfileProvider.notifier).load();
                      }
                    },
                  )),
                  const SizedBox(height: 8),
                  _Card(isDark: isDark, cs: cs, child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance_wallet_outlined,
                          color: cs.onSurface, size: 18),
                    ),
                    title: Text('Manage Accounts', style: tt.bodyLarge),
                    subtitle: Text(
                        ref.watch(accountsProvider).valueOrNull?.length == 1
                            ? '1 account'
                            : '${ref.watch(accountsProvider).valueOrNull?.length ?? ''} accounts',
                        style: tt.bodySmall),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AccountsScreen()),
                    ),
                  )),

                  const SizedBox(height: 20),

                  // ── Currency ─────────────────────────────
                  _Header('CURRENCY'),
                  _Card(
                    isDark: isDark,
                    cs: cs,
                    child: Column(
                      children: supportedCurrencies.asMap().entries.map((e) {
                        final c       = e.value;
                        final isLast  = e.key == supportedCurrencies.length - 1;
                        final isSel   = c.code == currency.code;
                        return Column(children: [
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? cs.onSurface.withAlpha(15)
                                    : cs.onSurface.withAlpha(8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(c.symbol,
                                    style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isSel
                                            ? cs.onSurface
                                            : cs.onSurfaceVariant)),
                              ),
                            ),
                            title: Text(c.name, style: tt.bodyLarge),
                            subtitle: Text(c.code, style: tt.bodySmall),
                            trailing: isSel
                                ? Icon(Icons.check_circle_rounded,
                                    color: cs.primary, size: 20)
                                : null,
                            onTap: () async {
                                ref.read(currencyProvider.notifier).setCurrency(c);
                                // Also persist to the selected account in DB
                                final accountId =
                                    ref.read(selectedAccountProvider);
                                await ref
                                    .read(databaseProvider)
                                    .updateAccount(
                                      accountId,
                                      AccountsCompanion(
                                          currencyCode: Value(c.code)),
                                    );
                              },
                          ),
                          if (!isLast)
                            Divider(height: 1, indent: 64, endIndent: 16, color: cs.outline),
                        ]);
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Gemini ────────────────────────────────
                  _Header('AI'),
                  _ApiKeyTile(isDark: isDark, cs: cs, tt: tt, currentKey: apiKey),
                  const SizedBox(height: 20),

                  // ── Export ──────────────────────────────────
                  _Header('DATA'),
                  _Card(isDark: isDark, cs: cs, child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.download_rounded,
                          color: cs.onSurface, size: 18),
                    ),
                    title: Text('Export Report', style: tt.bodyLarge),
                    subtitle: Text('Excel • Monthly or yearly',
                        style: tt.bodySmall),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExportReportScreen()),
                    ),
                  )),
                  const SizedBox(height: 8),
                  _Card(isDark: isDark, cs: cs, child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.backup_outlined,
                          color: cs.onSurface, size: 18),
                    ),
                    title: Text('Backup & Restore', style: tt.bodyLarge),
                    subtitle: Text('Export or import all data as JSON',
                        style: tt.bodySmall),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BackupScreen()),
                    ),
                  )),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  const _Header(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
              ),
        ),
      );
}

class _Card extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final Widget child;
  const _Card({required this.isDark, required this.cs, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline, width: isDark ? 0.5 : 1),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(20), child: child),
      );
}

class _ApiKeyTile extends ConsumerStatefulWidget {
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final String? currentKey;
  const _ApiKeyTile(
      {required this.isDark,
      required this.cs,
      required this.tt,
      required this.currentKey});

  @override
  ConsumerState<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends ConsumerState<_ApiKeyTile> {
  late final TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentKey ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _Card(
        isDark: widget.isDark,
        cs: widget.cs,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.vpn_key_outlined, color: widget.cs.onSurface, size: 20),
                const SizedBox(width: 10),
                Text('Gemini API Key', style: widget.tt.bodyLarge),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                obscureText: _obscure,
                style: widget.tt.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final key = _ctrl.text.trim();
                    ref.read(apiKeyProvider.notifier).state = key;
                    ref.read(geminiServiceProvider).setApiKey(key);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('API key saved'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: const Text('Save Key'),
                ),
              ),
            ],
          ),
        ),
      );
}
