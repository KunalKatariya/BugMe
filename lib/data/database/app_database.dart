import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

// ── Table definitions ──────────────────────────────────────────────────────

/// A single recorded expense transaction.
/// [txnType] is one of: 'expense' | 'investment' | 'recurring'
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 36, max: 36)();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawInput => text().nullable()();
  IntColumn get accountId => integer().withDefault(const Constant(1))();
  /// 'expense' | 'investment' | 'recurring'
  TextColumn get txnType =>
      text().withDefault(const Constant('expense'))();
}

/// Monthly budget allocation per category.
class BudgetAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text().withLength(min: 7, max: 7)();
  TextColumn get category => text()();
  RealColumn get allocatedAmount => real()();
  IntColumn get accountId => integer().withDefault(const Constant(1))();
}

/// A savings account (e.g. Indian bank, Japanese bank).
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🏦'))();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A savings goal with optional monthly SIP automation.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🎯'))();
  RealColumn get targetAmount => real()();
  RealColumn get savedAmount => real().withDefault(const Constant(0.0))();
  /// Auto-contribution amount per month (null = no SIP).
  RealColumn get sipAmount => real().nullable()();
  /// Day of month to deduct SIP (1–28).
  IntColumn get sipDay => integer().withDefault(const Constant(1))();
  /// Last month when SIP was auto-executed (tracks duplicates).
  DateTimeColumn get sipLastContributed => dateTime().nullable()();
  DateTimeColumn get deadline => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get accountId => integer().withDefault(const Constant(1))();
}

/// A recurring payment that auto-generates transactions when due.
class RecurringPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  /// 'daily', 'weekly', 'monthly', 'yearly'
  TextColumn get frequency => text()();
  /// Day of month for monthly frequency (1–28); null means "same day as created"
  IntColumn get dayOfMonth => integer().nullable()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get accountId => integer().withDefault(const Constant(1))();
}

// ── Database class ─────────────────────────────────────────────────────────

@DriftDatabase(tables: [Transactions, BudgetAllocations, Goals, Accounts, RecurringPayments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(goals);
          }
          if (from < 3) {
            await m.addColumn(goals, goals.sipAmount);
            await m.addColumn(goals, goals.sipDay);
            await m.addColumn(goals, goals.sipLastContributed);
          }
          if (from < 4) {
            await m.createTable(accounts);
            // Insert the default 'Personal' account (gets id = 1)
            await customStatement(
              "INSERT INTO accounts (name, emoji, currency_code, created_at) VALUES ('Personal', '🏦', 'INR', ?)",
              [DateTime.now().millisecondsSinceEpoch ~/ 1000],
            );
            await m.addColumn(transactions, transactions.accountId);
            await m.addColumn(budgetAllocations, budgetAllocations.accountId);
            await m.addColumn(goals, goals.accountId);
          }
          if (from < 5) {
            await m.createTable(recurringPayments);
          }
          if (from < 6) {
            // Add transaction type column; existing rows default to 'expense'
            await m.addColumn(transactions, transactions.txnType);
          }
        },
      );

  // ── Accounts ──────────────────────────────────────────────

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<Account?> getAccount(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<void> updateAccount(int id, AccountsCompanion entry) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(entry);

  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  // ── Transactions ──────────────────────────────────────────

  Stream<List<Transaction>> watchTransactionsForMonth(String month, int accountId) {
    return (select(transactions)
          ..where(
            (t) => t.date.year.equals(int.parse(month.split('-')[0])) &
                t.date.month.equals(int.parse(month.split('-')[1])) &
                t.accountId.equals(accountId),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<bool> updateTransaction(Transaction entry) =>
      update(transactions).replace(entry);

  Future<Map<String, double>> spendPerCategory(String month, int accountId) async {
    final year = int.parse(month.split('-')[0]);
    final mon  = int.parse(month.split('-')[1]);
    final rows = await (select(transactions)
          ..where((t) =>
              t.date.year.equals(year) &
              t.date.month.equals(mon) &
              t.accountId.equals(accountId)))
        .get();
    final map = <String, double>{};
    for (final row in rows) {
      // Only discretionary expenses count against category budgets
      if (row.txnType == 'expense') {
        map[row.category] = (map[row.category] ?? 0) + row.amount;
      }
    }
    return map;
  }

  // ── Budget Allocations ────────────────────────────────────

  Stream<List<BudgetAllocation>> watchAllocationsForMonth(String month, int accountId) =>
      (select(budgetAllocations)
            ..where((b) => b.month.equals(month) & b.accountId.equals(accountId)))
          .watch();

  Future<void> upsertAllocation(BudgetAllocationsCompanion entry) async {
    final acctId = entry.accountId.present ? entry.accountId.value : 1;
    final existing = await (select(budgetAllocations)
          ..where((b) =>
              b.month.equals(entry.month.value) &
              b.category.equals(entry.category.value) &
              b.accountId.equals(acctId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(budgetAllocations)..where((b) => b.id.equals(existing.id)))
          .write(BudgetAllocationsCompanion(
              allocatedAmount: entry.allocatedAmount));
    } else {
      await into(budgetAllocations).insert(entry);
    }
  }

  Future<int> deleteAllocationsForMonth(String month, int accountId) =>
      (delete(budgetAllocations)
            ..where((b) => b.month.equals(month) & b.accountId.equals(accountId)))
          .go();

  Future<int> deleteAllocation(int id) =>
      (delete(budgetAllocations)..where((b) => b.id.equals(id))).go();

  // ── Goals ─────────────────────────────────────────────────

  Stream<List<Goal>> watchGoals(int accountId) =>
      (select(goals)
            ..where((g) => g.accountId.equals(accountId))
            ..orderBy([(g) => OrderingTerm.asc(g.deadline)]))
          .watch();

  Future<int> insertGoal(GoalsCompanion entry) =>
      into(goals).insert(entry);

  Future<int> deleteGoal(int id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();

  Future<void> contributeToGoal(int id, double amount) async {
    final goal = await (select(goals)..where((g) => g.id.equals(id))).getSingle();
    await (update(goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(savedAmount: Value(goal.savedAmount + amount)),
    );
  }

  Future<void> updateGoal(int id, GoalsCompanion entry) =>
      (update(goals)..where((g) => g.id.equals(id))).write(entry);

  Future<void> updateAllocationAmount(int id, double newAmount) =>
      (update(budgetAllocations)..where((b) => b.id.equals(id))).write(
        BudgetAllocationsCompanion(allocatedAmount: Value(newAmount)),
      );

  Future<List<Transaction>> getTransactionsForMonth(String month, int accountId) {
    final year = int.parse(month.split('-')[0]);
    final mon  = int.parse(month.split('-')[1]);
    return (select(transactions)
          ..where((t) =>
              t.date.year.equals(year) &
              t.date.month.equals(mon) &
              t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<List<Transaction>> getTransactionsForYear(int year, int accountId) =>
      (select(transactions)
            ..where((t) =>
                t.date.year.equals(year) & t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  Future<List<BudgetAllocation>> getAllocationsForYear(int year, int accountId) async {
    final all = await (select(budgetAllocations)
          ..where((b) => b.accountId.equals(accountId)))
        .get();
    return all.where((b) => b.month.startsWith('$year-')).toList();
  }

  /// Automatically apply SIP contributions where due (call on app launch).
  Future<void> processSipContributions() async {
    final now  = DateTime.now();
    final list = await select(goals).get();
    for (final goal in list) {
      if (goal.sipAmount == null || goal.sipAmount! <= 0) continue;
      if (goal.savedAmount >= goal.targetAmount) continue;
      final sipDate = DateTime(now.year, now.month, goal.sipDay.clamp(1, 28));
      if (now.isBefore(sipDate)) continue;
      if (goal.sipLastContributed != null) {
        final last = goal.sipLastContributed!;
        if (last.year == now.year && last.month == now.month) continue;
      }
      final remaining   = goal.targetAmount - goal.savedAmount;
      final contribution = goal.sipAmount! < remaining ? goal.sipAmount! : remaining;
      await (update(goals)..where((g) => g.id.equals(goal.id))).write(
        GoalsCompanion(
          savedAmount: Value(goal.savedAmount + contribution),
          sipLastContributed: Value(now),
        ),
      );
      // Record as an investment transaction (excluded from category budgets)
      const uuid = Uuid();
      await insertTransaction(TransactionsCompanion.insert(
        uuid: uuid.v4(),
        amount: contribution,
        category: 'Investments',
        description: 'SIP – ${goal.name}',
        date: now,
        accountId: Value(goal.accountId),
        txnType: const Value('investment'),
      ));
    }
  }

  // ── Recurring Payments ────────────────────────────────────

  Stream<List<RecurringPayment>> watchRecurringPayments(int accountId) =>
      (select(recurringPayments)
            ..where((r) =>
                r.accountId.equals(accountId) &
                r.isActive.equals(true))
            ..orderBy([(r) => OrderingTerm.asc(r.nextDueDate)]))
          .watch();

  Future<int> insertRecurringPayment(RecurringPaymentsCompanion entry) =>
      into(recurringPayments).insert(entry);

  Future<void> updateRecurringPayment(
          int id, RecurringPaymentsCompanion entry) =>
      (update(recurringPayments)..where((r) => r.id.equals(id))).write(entry);

  Future<int> deleteRecurringPayment(int id) =>
      (delete(recurringPayments)..where((r) => r.id.equals(id))).go();

  /// Auto-process overdue recurring payments (call on app launch).
  Future<void> processRecurringPayments() async {
    final now  = DateTime.now();
    final list = await (select(recurringPayments)
          ..where((r) => r.isActive.equals(true)))
        .get();
    const uuid = Uuid();
    for (final r in list) {
      if (r.nextDueDate.isAfter(now)) continue;
      // Create transaction tagged as recurring (excluded from category budgets)
      await insertTransaction(TransactionsCompanion.insert(
        uuid: uuid.v4(),
        amount: r.amount,
        category: r.category,
        description: r.label,
        date: r.nextDueDate,
        accountId: Value(r.accountId),
        txnType: const Value('recurring'),
      ));
      // Advance nextDueDate
      DateTime next;
      switch (r.frequency) {
        case 'daily':
          next = r.nextDueDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = r.nextDueDate.add(const Duration(days: 7));
          break;
        case 'yearly':
          next = DateTime(r.nextDueDate.year + 1, r.nextDueDate.month,
              r.nextDueDate.day);
          break;
        case 'monthly':
        default:
          final dom = r.dayOfMonth ?? r.nextDueDate.day;
          var y = r.nextDueDate.year;
          var m = r.nextDueDate.month + 1;
          if (m > 12) { m = 1; y++; }
          next = DateTime(y, m, dom.clamp(1, 28));
      }
      await (update(recurringPayments)
            ..where((rec) => rec.id.equals(r.id)))
          .write(RecurringPaymentsCompanion(nextDueDate: Value(next)));
    }
  }

  // ── Backup / Restore ─────────────────────────────────────

  /// Export all data as a Map ready for JSON serialization.
  Future<Map<String, dynamic>> exportAllData() async {
    final accs  = await select(accounts).get();
    final txns  = await select(transactions).get();
    final alloc = await select(budgetAllocations).get();
    final gls   = await select(goals).get();
    final recs  = await (select(recurringPayments)
          ..where((r) => r.isActive.equals(true)))
        .get();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accs.map((a) => {
            'id': a.id,
            'name': a.name,
            'emoji': a.emoji,
            'currencyCode': a.currencyCode,
            'createdAt': a.createdAt.toIso8601String(),
          }).toList(),
      'transactions': txns.map((t) => {
            'uuid': t.uuid,
            'amount': t.amount,
            'category': t.category,
            'description': t.description,
            'date': t.date.toIso8601String(),
            'createdAt': t.createdAt.toIso8601String(),
            'rawInput': t.rawInput,
            'accountId': t.accountId,
            'txnType': t.txnType,
          }).toList(),
      'allocations': alloc.map((b) => {
            'month': b.month,
            'category': b.category,
            'allocatedAmount': b.allocatedAmount,
            'accountId': b.accountId,
          }).toList(),
      'goals': gls.map((g) => {
            'name': g.name,
            'emoji': g.emoji,
            'targetAmount': g.targetAmount,
            'savedAmount': g.savedAmount,
            'sipAmount': g.sipAmount,
            'sipDay': g.sipDay,
            'deadline': g.deadline.toIso8601String(),
            'createdAt': g.createdAt.toIso8601String(),
            'accountId': g.accountId,
          }).toList(),
      'recurring': recs.map((r) => {
            'label': r.label,
            'category': r.category,
            'amount': r.amount,
            'frequency': r.frequency,
            'dayOfMonth': r.dayOfMonth,
            'nextDueDate': r.nextDueDate.toIso8601String(),
            'accountId': r.accountId,
          }).toList(),
    };
  }

  /// Replace all data with the provided backup map.
  Future<void> importAllData(Map<String, dynamic> data) async {
    await transaction(() async {
      // Delete all existing rows
      await delete(transactions).go();
      await delete(budgetAllocations).go();
      await delete(goals).go();
      await delete(recurringPayments).go();
      // Keep accounts but clear them too
      await delete(accounts).go();

      // Insert accounts first to preserve IDs
      for (final a in (data['accounts'] as List)) {
        await customInsert(
          'INSERT INTO accounts (id, name, emoji, currency_code, created_at) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable(a['id'] as int),
            Variable(a['name'] as String),
            Variable(a['emoji'] as String),
            Variable(a['currencyCode'] as String),
            Variable(DateTime.parse(a['createdAt'] as String)),
          ],
        );
      }
      // Insert transactions
      for (final t in (data['transactions'] as List)) {
        await into(transactions).insert(TransactionsCompanion.insert(
          uuid: t['uuid'] as String,
          amount: (t['amount'] as num).toDouble(),
          category: t['category'] as String,
          description: t['description'] as String,
          date: DateTime.parse(t['date'] as String),
          accountId: Value(t['accountId'] as int),
          rawInput: Value(t['rawInput'] as String?),
          txnType: Value(t['txnType'] as String? ?? 'expense'),
        ));
      }
      // Insert allocations
      for (final b in (data['allocations'] as List)) {
        await into(budgetAllocations)
            .insert(BudgetAllocationsCompanion.insert(
          month: b['month'] as String,
          category: b['category'] as String,
          allocatedAmount: (b['allocatedAmount'] as num).toDouble(),
          accountId: Value(b['accountId'] as int),
        ));
      }
      // Insert goals
      for (final g in (data['goals'] as List)) {
        await into(goals).insert(GoalsCompanion.insert(
          name: g['name'] as String,
          emoji: Value(g['emoji'] as String),
          targetAmount: (g['targetAmount'] as num).toDouble(),
          savedAmount:
              Value((g['savedAmount'] as num? ?? 0).toDouble()),
          sipAmount: Value(
              g['sipAmount'] != null
                  ? (g['sipAmount'] as num).toDouble()
                  : null),
          sipDay: Value(g['sipDay'] as int? ?? 1),
          deadline: DateTime.parse(g['deadline'] as String),
          accountId: Value(g['accountId'] as int),
        ));
      }
      // Insert recurring payments
      for (final r in (data['recurring'] as List? ?? [])) {
        await into(recurringPayments)
            .insert(RecurringPaymentsCompanion.insert(
          label: r['label'] as String,
          category: r['category'] as String,
          amount: (r['amount'] as num).toDouble(),
          frequency: r['frequency'] as String,
          dayOfMonth: Value(r['dayOfMonth'] as int?),
          nextDueDate:
              DateTime.parse(r['nextDueDate'] as String),
          accountId: Value(r['accountId'] as int),
        ));
      }
    });
  }

  // ── Daily spend stream ────────────────────────────────────

  Stream<Map<int, double>> watchDailySpendForMonth(String month, int accountId) {
    final year = int.parse(month.split('-')[0]);
    final mon  = int.parse(month.split('-')[1]);
    return (select(transactions)
          ..where((t) =>
              t.date.year.equals(year) &
              t.date.month.equals(mon) &
              t.accountId.equals(accountId)))
        .watch()
        .map((rows) {
      final map = <int, double>{};
      for (final r in rows) {
        map[r.date.day] = (map[r.date.day] ?? 0) + r.amount;
      }
      return map;
    });
  }

  // ── Budget carry-forward ──────────────────────────────────

  Future<void> carryForwardAllocations(
      String fromMonth, String toMonth, int accountId) async {
    final existing = await (select(budgetAllocations)
          ..where((b) =>
              b.month.equals(toMonth) & b.accountId.equals(accountId)))
        .get();
    if (existing.isNotEmpty) return;
    final source = await (select(budgetAllocations)
          ..where((b) =>
              b.month.equals(fromMonth) & b.accountId.equals(accountId)))
        .get();
    for (final a in source) {
      await upsertAllocation(BudgetAllocationsCompanion.insert(
        month: toMonth,
        category: a.category,
        allocatedAmount: a.allocatedAmount,
        accountId: Value(accountId),
      ));
    }
  }
}

// ── Connection helper ──────────────────────────────────────────────────────

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'bugme_db',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationDocumentsDirectory,
    ),
  );
}
