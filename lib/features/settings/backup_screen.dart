import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers/app_providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt     = Theme.of(context).textTheme;
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

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
              icon: Icon(Icons.arrow_back_ios_new,
                  color: cs.onSurface, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Backup & Restore', style: tt.headlineMedium),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save a copy of all your data or restore from a previous backup.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),

                  // ── Export section ─────────────────────────────────
                  _SectionLabel(label: 'EXPORT', tt: tt, cs: cs),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.upload_outlined,
                    title: 'Export Backup',
                    subtitle:
                        'Save all accounts, transactions, budgets and goals to a JSON file.',
                    cs: cs,
                    tt: tt,
                    isDark: isDark,
                    onTap: () => _export(context, ref),
                  ),

                  const SizedBox(height: 24),

                  // ── Import section ─────────────────────────────────
                  _SectionLabel(label: 'RESTORE', tt: tt, cs: cs),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.download_outlined,
                    title: 'Restore from Backup',
                    subtitle:
                        'Replace all current data with a backup file.\n⚠️ This cannot be undone.',
                    cs: cs,
                    tt: tt,
                    isDark: isDark,
                    onTap: () => _import(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Preparing backup...'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ));

      final data =
          await ref.read(databaseProvider).exportAllData();
      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'bugme_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'BugMe Backup – $fileName',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;

    // Confirm before proceeding
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'This will replace ALL current data (accounts, transactions, budgets, goals) with the backup.\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text('Restore', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      // ── Decode ──────────────────────────────────────────────────────────
      late Map<String, dynamic> data;
      try {
        final jsonStr = utf8.decode(bytes);
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } on FormatException {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Invalid file: not valid JSON.'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not read file.'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      // ── Validate structure ───────────────────────────────────────────────
      final version = data['version'];
      if (version == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Invalid backup: missing version field.'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      const requiredKeys = ['accounts', 'transactions', 'allocations', 'goals'];
      for (final key in requiredKeys) {
        if (!data.containsKey(key) || data[key] is! List) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invalid backup: missing or malformed "$key" section.'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          return;
        }
      }

      final accounts = data['accounts'] as List;
      if (accounts.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Invalid backup: no accounts found.'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      await ref.read(databaseProvider).importAllData(data);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Backup restored successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Restore failed: $e'),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final TextTheme tt;
  final ColorScheme cs;
  const _SectionLabel(
      {required this.label, required this.tt, required this.cs});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3.5,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: cs.onSurface.withAlpha(180),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(label,
              style: tt.labelLarge
                  ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        ],
      );
}

// ── Action card ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline, width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: cs.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      );
}
