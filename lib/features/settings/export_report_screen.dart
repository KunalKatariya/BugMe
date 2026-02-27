import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../data/providers/app_providers.dart';

class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() =>
      _ExportReportScreenState();
}

enum _ExportMode { monthly, yearly }

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  _ExportMode _mode = _ExportMode.monthly;
  bool _loading = false;

  // Month picker state
  late int _selectedYear;
  late int _selectedMonth;

  // Year picker state
  late int _selectedYearOnly;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear      = now.year;
    _selectedMonth     = now.month;
    _selectedYearOnly  = now.year;
  }

  String get _monthKey =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
  }

  // ── Excel generation ────────────────────────────────────────────────────

  CellStyle _headerStyle(Excel excel) => CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1A1A2E'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

  void _applyHeader(Sheet sheet, List<String> cols, Excel excel) {
    sheet.appendRow(cols.map((c) => TextCellValue(c)).toList());
    // Bold the first row
    for (var i = 0; i < cols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: i, rowIndex: 0));
      cell.cellStyle = _headerStyle(excel);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final db        = ref.read(databaseProvider);
      final currency  = ref.read(currencyProvider);
      final accountId = ref.read(selectedAccountProvider);
      final goals     = await db.watchGoals(accountId).first;
      final excel     = Excel.createExcel();
      // Remove default empty sheet
      excel.delete('Sheet1');

      if (_mode == _ExportMode.monthly) {
        await _buildMonthlyReport(excel, db, currency, goals, accountId);
      } else {
        await _buildYearlyReport(excel, db, currency, goals, accountId);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to encode Excel file.');

      final dir  = await getApplicationDocumentsDirectory();
      final name = _mode == _ExportMode.monthly
          ? 'bugme_$_monthKey.xlsx'
          : 'bugme_$_selectedYearOnly.xlsx';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'BugMe Financial Report',
        text: _mode == _ExportMode.monthly
            ? 'Financial report for $_monthLabel'
            : 'Financial report for $_selectedYearOnly',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Monthly report sheets ────────────────────────────────────────────────

  Future<void> _buildMonthlyReport(
      Excel excel,
      dynamic db,
      AppCurrency currency,
      List<dynamic> goals,
      int accountId) async {
    final txns   = await db.getTransactionsForMonth(_monthKey, accountId);
    final allocs = await db.watchAllocationsForMonth(_monthKey, accountId).first;

    // ── Sheet 1: Transactions ──────────────────────────────────────────
    final txnSheet = excel['Transactions'];
    _applyHeader(txnSheet, [
      'Date', 'Weekday', 'Description', 'Category',
      'Amount (${currency.code})',
    ], excel);

    double runningTotal = 0;
    final fmt = DateFormat('dd MMM yyyy');
    for (final t in txns) {
      runningTotal += t.amount as double;
      txnSheet.appendRow([
        TextCellValue(fmt.format(t.date as DateTime)),
        TextCellValue(DateFormat('EEEE').format(t.date as DateTime)),
        TextCellValue(t.description as String),
        TextCellValue(t.category as String),
        DoubleCellValue(t.amount as double),
      ]);
    }
    // Summary row
    txnSheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('TOTAL'),
      DoubleCellValue(runningTotal),
    ]);

    // ── Sheet 2: Budget ────────────────────────────────────────────────
    final spendMap = <String, double>{};
    for (final t in txns) {
      // Only discretionary expenses count against category budgets
      if ((t.txnType as String? ?? 'expense') != 'expense') continue;
      final cat = t.category as String;
      spendMap[cat] = (spendMap[cat] ?? 0) + (t.amount as double);
    }

    final budgetSheet = excel['Budget'];
    _applyHeader(budgetSheet, [
      'Category', 'Budgeted (${currency.code})',
      'Spent (${currency.code})', 'Remaining (${currency.code})', 'Status',
    ], excel);

    double totalBudget = 0, totalSpent = 0;
    for (final a in allocs) {
      final spent     = spendMap[a.category as String] ?? 0.0;
      final budgeted  = a.allocatedAmount as double;
      final remaining = budgeted - spent;
      totalBudget += budgeted;
      totalSpent  += spent;
      budgetSheet.appendRow([
        TextCellValue(a.category as String),
        DoubleCellValue(budgeted),
        DoubleCellValue(spent),
        DoubleCellValue(remaining),
        TextCellValue(remaining < 0 ? 'Over Budget' : 'Within Budget'),
      ]);
    }
    // Also show categories with spending but no allocation
    for (final entry in spendMap.entries) {
      final hasAlloc =
          allocs.any((a) => (a.category as String) == entry.key);
      if (!hasAlloc) {
        budgetSheet.appendRow([
          TextCellValue(entry.key),
          DoubleCellValue(0),
          DoubleCellValue(entry.value),
          DoubleCellValue(-entry.value),
          TextCellValue('No Budget Set'),
        ]);
      }
    }
    // Totals
    budgetSheet.appendRow([
      TextCellValue('TOTAL'),
      DoubleCellValue(totalBudget),
      DoubleCellValue(totalSpent),
      DoubleCellValue(totalBudget - totalSpent),
      TextCellValue(totalSpent > totalBudget ? 'Over Budget' : 'Within Budget'),
    ]);

    // ── Sheet 3: Goals ─────────────────────────────────────────────────
    _buildGoalsSheet(excel, goals, currency);
  }

  // ── Yearly report sheets ─────────────────────────────────────────────────

  Future<void> _buildYearlyReport(
      Excel excel,
      dynamic db,
      AppCurrency currency,
      List<dynamic> goals,
      int accountId) async {
    final allTxns   = await db.getTransactionsForYear(_selectedYearOnly, accountId);
    final allAllocs = await db.getAllocationsForYear(_selectedYearOnly, accountId);
    final months    = List.generate(12, (i) =>
        '$_selectedYearOnly-${(i + 1).toString().padLeft(2, '0')}');

    // Pre-compute spend per month and per category+month
    final monthlySpend = <String, double>{};
    final catMonthSpend = <String, Map<String, double>>{};
    final catSpend = <String, double>{};
    final fmt = DateFormat('dd MMM yyyy');

    for (final t in allTxns) {
      final m   = DateFormat('yyyy-MM').format(t.date as DateTime);
      final cat = t.category as String;
      final amt = t.amount as double;
      // Monthly total shows all outflows; category breakdown is expenses only
      monthlySpend[m] = (monthlySpend[m] ?? 0) + amt;
      if ((t.txnType as String? ?? 'expense') == 'expense') {
        catMonthSpend[cat] ??= {};
        catMonthSpend[cat]![m] = (catMonthSpend[cat]![m] ?? 0) + amt;
        catSpend[cat] = (catSpend[cat] ?? 0) + amt;
      }
    }

    // ── Sheet 1: Monthly Summary ───────────────────────────────────────
    final summarySheet = excel['Monthly Summary'];
    _applyHeader(summarySheet, [
      'Month', 'Total Spent (${currency.code})',
      'Total Budgeted (${currency.code})',
      'Remaining (${currency.code})', 'Status',
    ], excel);

    for (final m in months) {
      final spent = monthlySpend[m] ?? 0.0;
      final budgeted = allAllocs
          .where((a) => (a.month as String) == m)
          .fold(0.0, (s, a) => s + (a.allocatedAmount as double));
      final remaining = budgeted - spent;
      summarySheet.appendRow([
        TextCellValue(DateFormat('MMMM yyyy').format(DateTime.parse('$m-01'))),
        DoubleCellValue(spent),
        DoubleCellValue(budgeted),
        DoubleCellValue(remaining),
        TextCellValue(budgeted == 0
            ? 'No Budget'
            : remaining < 0
                ? 'Over Budget'
                : 'Within Budget'),
      ]);
    }

    // ── Sheet 2: Category Breakdown ────────────────────────────────────
    final catSheet = excel['Category Breakdown'];
    final catHeaders = [
      'Category',
      ...months.map((m) => DateFormat('MMM').format(DateTime.parse('$m-01'))),
      'Total (${currency.code})',
    ];
    _applyHeader(catSheet, catHeaders, excel);

    final sortedCats = catMonthSpend.keys.toList()
      ..sort((a, b) => (catSpend[b] ?? 0).compareTo(catSpend[a] ?? 0));
    for (final cat in sortedCats) {
      final row = <CellValue>[TextCellValue(cat)];
      for (final m in months) {
        row.add(DoubleCellValue(catMonthSpend[cat]![m] ?? 0));
      }
      row.add(DoubleCellValue(catSpend[cat] ?? 0));
      catSheet.appendRow(row);
    }

    // ── Sheet 3: All Transactions ─────────────────────────────────────
    final txnSheet = excel['All Transactions'];
    _applyHeader(txnSheet, [
      'Date', 'Weekday', 'Month', 'Description',
      'Category', 'Amount (${currency.code})',
    ], excel);

    for (final t in allTxns) {
      txnSheet.appendRow([
        TextCellValue(fmt.format(t.date as DateTime)),
        TextCellValue(DateFormat('EEEE').format(t.date as DateTime)),
        TextCellValue(DateFormat('MMMM').format(t.date as DateTime)),
        TextCellValue(t.description as String),
        TextCellValue(t.category as String),
        DoubleCellValue(t.amount as double),
      ]);
    }

    // ── Sheet 4: Goals ─────────────────────────────────────────────────
    _buildGoalsSheet(excel, goals, currency);
  }

  // ── Shared goals sheet ───────────────────────────────────────────────────

  void _buildGoalsSheet(Excel excel, List<dynamic> goals, AppCurrency currency) {
    final sheet = excel['Goals'];
    _applyHeader(sheet, [
      'Goal', 'Emoji', 'Target (${currency.code})',
      'Saved (${currency.code})', 'Progress %',
      'Auto SIP (${currency.code}/mo)', 'SIP Day',
      'Deadline', 'Status',
    ], excel);

    for (final g in goals) {
      final target   = g.targetAmount as double;
      final saved    = g.savedAmount  as double;
      final pct      = target > 0 ? ((saved / target) * 100).toStringAsFixed(1) : '0.0';
      final isDone   = saved >= target;
      final daysLeft = (g.deadline as DateTime).difference(DateTime.now()).inDays;
      final status   = isDone
          ? 'Achieved ✓'
          : daysLeft < 0
              ? 'Overdue'
              : '$daysLeft days left';

      sheet.appendRow([
        TextCellValue(g.name as String),
        TextCellValue(g.emoji as String),
        DoubleCellValue(target),
        DoubleCellValue(saved),
        TextCellValue('$pct%'),
        g.sipAmount != null
            ? DoubleCellValue(g.sipAmount as double)
            : TextCellValue('—'),
        g.sipAmount != null
            ? IntCellValue(g.sipDay as int)
            : TextCellValue('—'),
        TextCellValue(DateFormat('dd MMM yyyy').format(g.deadline as DateTime)),
        TextCellValue(status),
      ]);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        scrolledUnderElevation: 0,
        title: Text('Export Report', style: tt.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode toggle ─────────────────────────────────────────────
            _SectionLabel('EXPORT TYPE', tt),
            _Card(isDark: isDark, cs: cs,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Monthly',
                        icon: Icons.calendar_month_outlined,
                        selected: _mode == _ExportMode.monthly,
                        isDark: isDark, cs: cs, tt: tt,
                        onTap: () =>
                            setState(() => _mode = _ExportMode.monthly),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeButton(
                        label: 'Yearly',
                        icon: Icons.bar_chart_rounded,
                        selected: _mode == _ExportMode.yearly,
                        isDark: isDark, cs: cs, tt: tt,
                        onTap: () =>
                            setState(() => _mode = _ExportMode.yearly),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Period selector ─────────────────────────────────────────
            _SectionLabel(
                _mode == _ExportMode.monthly ? 'SELECT MONTH' : 'SELECT YEAR',
                tt),
            _Card(isDark: isDark, cs: cs,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ArrowBtn(
                      icon: Icons.chevron_left,
                      onTap: _mode == _ExportMode.monthly
                          ? () => _shiftMonth(-1)
                          : () => setState(() => _selectedYearOnly--),
                    ),
                    Text(
                      _mode == _ExportMode.monthly
                          ? _monthLabel
                          : '$_selectedYearOnly',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    _ArrowBtn(
                      icon: Icons.chevron_right,
                      onTap: _mode == _ExportMode.monthly
                          ? () => _shiftMonth(1)
                          : () => setState(() => _selectedYearOnly++),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── What's included ─────────────────────────────────────────
            _SectionLabel('INCLUDES', tt),
            _Card(isDark: isDark, cs: cs,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: _mode == _ExportMode.monthly
                    ? _monthlyInfoItems(tt, cs)
                    : _yearlyInfoItems(tt, cs)),
              ),
            ),

            const SizedBox(height: 32),

            // ── Generate button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _loading ? 'Generating...' : 'Generate & Export',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.onSurface,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'The Excel file will be generated and shared via your device\'s share sheet.',
              style: tt.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _monthlyInfoItems(TextTheme tt, ColorScheme cs) => [
    _InfoRow(icon: Icons.receipt_long_outlined,
        label: 'Sheet 1: Transactions',
        sub: 'Date, weekday, description, category, amount', tt: tt, cs: cs),
    _InfoRow(icon: Icons.pie_chart_outline_rounded,
        label: 'Sheet 2: Budget',
        sub: 'Category budgets vs actual spending', tt: tt, cs: cs),
    _InfoRow(icon: Icons.flag_outlined,
        label: 'Sheet 3: Goals',
        sub: 'All goals with progress and SIP details', tt: tt, cs: cs),
  ];

  List<Widget> _yearlyInfoItems(TextTheme tt, ColorScheme cs) => [
    _InfoRow(icon: Icons.calendar_today_outlined,
        label: 'Sheet 1: Monthly Summary',
        sub: 'Month-by-month spend vs budget', tt: tt, cs: cs),
    _InfoRow(icon: Icons.grid_on_rounded,
        label: 'Sheet 2: Category Breakdown',
        sub: 'Spend per category for each month', tt: tt, cs: cs),
    _InfoRow(icon: Icons.receipt_long_outlined,
        label: 'Sheet 3: All Transactions',
        sub: 'Every transaction across the year', tt: tt, cs: cs),
    _InfoRow(icon: Icons.flag_outlined,
        label: 'Sheet 4: Goals',
        sub: 'All goals with progress and SIP details', tt: tt, cs: cs),
  ];
}

// ── Supporting widgets ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final TextTheme tt;
  const _SectionLabel(this.label, this.tt);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label, style: tt.labelLarge),
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
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: child,
      );
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label, required this.icon, required this.selected,
    required this.isDark, required this.cs, required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? cs.onSurface
                : cs.onSurface.withAlpha(8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.onSurface : cs.outline,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : cs.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isDark ? Colors.black : Colors.white)
                        : cs.onSurfaceVariant)),
          ]),
        ),
      );
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cs.onSurface.withAlpha(10),
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline),
        ),
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final TextTheme tt;
  final ColorScheme cs;
  const _InfoRow({
    required this.icon, required this.label, required this.sub,
    required this.tt, required this.cs,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: cs.onSurface.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: tt.bodySmall),
              ],
            ),
          ),
        ]),
      );
}
